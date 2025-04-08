from flask import Flask, Response, request, stream_with_context, session
from flask_cors import CORS
from claude_streamer import stream_claude_response
#from thought_chain import create_thought_loop_chain
import os
import tempfile
import mimetypes
import base64
import uuid
import shutil
import json
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = os.urandom(24)  # Required for session
# Enable CORS for frontend calls with credentials support
CORS(app, supports_credentials=True)

# Create a directory to store uploaded files
UPLOAD_FOLDER = os.path.join(tempfile.gettempdir(), 'claude_uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Dictionary to store file information
file_storage = {}

@app.route("/")
def home():
    return "Claude 3.5 Streaming + LangChain Flask Service"

ALLOWED_EXTENSIONS = {'pdf', 'txt', 'jpg', 'jpeg', 'png', 'gif'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route("/stream", methods=["GET", "POST", "OPTIONS"])
def stream():
    # Handle preflight OPTIONS request
    if request.method == "OPTIONS":
        response = Response()
        response.headers.add('Access-Control-Allow-Origin', request.headers.get('Origin', '*'))
        response.headers.add('Access-Control-Allow-Credentials', 'true')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        return response
        
    files = []
    session_id = request.cookies.get('session_id')
    
    if not session_id:
        session_id = str(uuid.uuid4())
    
    if request.method == "POST":
        if request.content_type and 'multipart/form-data' in request.content_type:
            # Handle multipart form data (with files)
            question = request.form.get("question", "")
            extended_thinking = request.form.get("thinking", "false").lower() == "true"
            thinking_tokens = int(request.form.get("tokens", 1024))
            
            # Create session directory if it doesn't exist
            session_dir = os.path.join(UPLOAD_FOLDER, session_id)
            os.makedirs(session_dir, exist_ok=True)
            
            # Clear previous files for this session
            if session_id in file_storage:
                file_storage[session_id] = []
            
            # Process uploaded files
            for key in request.files:
                file = request.files[key]
                if file and allowed_file(file.filename):
                    filename = secure_filename(file.filename)
                    file_path = os.path.join(session_dir, filename)
                    file.save(file_path)
                    mime_type = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
                    file_info = {
                        'path': file_path,
                        'name': filename,
                        'type': mime_type
                    }
                    files.append(file_info)
                    
                    # Store file info for future requests
                    if session_id not in file_storage:
                        file_storage[session_id] = []
                    file_storage[session_id].append(file_info)
    else:
        # Handle JSON data or GET request
        if request.content_type and 'application/json' in request.content_type:
            data = request.get_json()
            question = data.get("question", "")
            extended_thinking = data.get("thinking", False)
            thinking_tokens = int(data.get("tokens", 1024))
        else:
            # Handle GET request
            question = request.args.get("question", "")
            extended_thinking = request.args.get("thinking", "false").lower() == "true"
            thinking_tokens = int(request.args.get("tokens", 1024))
            
            # Use stored files for this session
            if session_id in file_storage:
                files = file_storage[session_id]

    print(f"📩 question: '{question}' | 🧠 thinking: {extended_thinking} | 🔢 tokens: {thinking_tokens} | 📎 files: {len(files)}")

    def event_stream():
        for chunk in stream_claude_response(
            question, 
            files=files,
            extended_thinking=extended_thinking, 
            thinking_tokens=thinking_tokens
        ):
            yield chunk

    response = Response(
        stream_with_context(event_stream()),
        mimetype="text/event-stream"
    )
    
    # Add CORS headers explicitly
    response.headers.add('Access-Control-Allow-Origin', request.headers.get('Origin', '*'))
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    
    # Set session cookie with SameSite=None and Secure=True for cross-origin requests
    response.set_cookie('session_id', session_id, max_age=3600, samesite='None', secure=True)  # 1 hour expiry
    
    return response

@app.route("/clear_files", methods=["POST", "OPTIONS"])
def clear_files():
    """Clear files for a session"""
    # Handle preflight OPTIONS request
    if request.method == "OPTIONS":
        response = Response()
        response.headers.add('Access-Control-Allow-Origin', request.headers.get('Origin', '*'))
        response.headers.add('Access-Control-Allow-Credentials', 'true')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response
        
    session_id = request.cookies.get('session_id')
    if session_id and session_id in file_storage:
        # Delete files
        session_dir = os.path.join(UPLOAD_FOLDER, session_id)
        if os.path.exists(session_dir):
            shutil.rmtree(session_dir)
        
        # Clear from storage
        del file_storage[session_id]
    
    response = {"status": "success"}
    # Add CORS headers to the response
    response = Response(json.dumps(response), mimetype="application/json")
    response.headers.add('Access-Control-Allow-Origin', request.headers.get('Origin', '*'))
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    
    return response

if __name__ == "__main__":
    app.run(debug=True, port=5001)
