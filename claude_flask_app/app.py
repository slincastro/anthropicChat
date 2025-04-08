from flask import Flask, Response, request, stream_with_context
from flask_cors import CORS
from claude_streamer import stream_claude_response
from thought_chain import create_thought_loop_chain

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend calls

@app.route("/")
def home():
    return "Claude 3.5 Streaming + LangChain Flask Service"

@app.route("/stream", methods=["GET", "POST"])
def stream():
    if request.method == "POST":
        data = request.get_json()
        question = data.get("question", "")
        extended_thinking = data.get("thinking", False)
        thinking_tokens = int(data.get("tokens", 1024)) 
    else:
        question = request.args.get("question", "")
        extended_thinking = request.args.get("thinking", "false").lower() == "true"
        thinking_tokens = int(request.args.get("tokens", 1024)) 

    print(f"📩 question: '{question}' | 🧠 thinking: {extended_thinking} | 🔢 tokens: {thinking_tokens}")

    def event_stream():
        for chunk in stream_claude_response(
            question, extended_thinking=extended_thinking, thinking_tokens=thinking_tokens
        ):
            yield chunk

    response = Response(
        stream_with_context(event_stream()),
        mimetype="text/event-stream"
    )

    return response

if __name__ == "__main__":
    app.run(debug=True, port=5001)
