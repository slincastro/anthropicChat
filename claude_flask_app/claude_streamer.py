from litellm import completion
import os
import json
import os
import time
import json
import base64
from anthropic import Anthropic
from anthropic.types import MessageStreamEvent, ContentBlock, ImageBlockParam
import mimetypes
import PyPDF2
import io


# Load API key from config.json
with open('config.json', 'r') as f:
    config = json.load(f)
    CLAUDE_API_KEY = config['openai']['claude_key']



# Usa tu proxy LiteLLM como base_url
client = Anthropic(
    api_key=os.getenv("CLAUDE_API_KEY", CLAUDE_API_KEY),
    base_url="https://ipsos.litellm-prod.ai"  
)

def stream_claude_response(
    question: str,
    files: list = None,
    extended_thinking: bool = False,
    thinking_tokens: int = 1024,  
    model: str = "claude-3-7-sonnet-latest"
):
    if files is None:
        files = []
    start_time = time.time()
    print(f"🧠 Using extended thinking: {extended_thinking} with {thinking_tokens} tokens")

    thinking_param = (
        {"type": "enabled", "budget_tokens": thinking_tokens}
        if extended_thinking else None
    )

    # Prepare message content
    message_content = []
    
    # Add files to message content
    for file_info in files:
        file_path = file_info['path']
        file_type = file_info['type']
        
        # Handle different file types
        if file_type.startswith('image/'):
            # For images, use Claude's image capability
            with open(file_path, 'rb') as f:
                image_data = f.read()
                image_base64 = base64.b64encode(image_data).decode('utf-8')
                
            # Add image block
            message_content.append(
                ImageBlockParam(
                    type="image",
                    source={"type": "base64", "media_type": file_type, "data": image_base64}
                )
            )
        elif file_type == 'application/pdf' or file_type == 'text/plain':
            # For PDFs and text files, extract text and add as text
            with open(file_path, 'rb') as f:
                file_content = f.read()
                
            # Add text block with file content
            file_text = f"[File: {file_info['name']}]\n"
            if file_type == 'text/plain':
                try:
                    file_text += file_content.decode('utf-8')
                except UnicodeDecodeError:
                    file_text += "Error: Could not decode text file."
            elif file_type == 'application/pdf':
                try:
                    # Extract text from PDF
                    pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_content))
                    pdf_text = ""
                    for page_num in range(len(pdf_reader.pages)):
                        page = pdf_reader.pages[page_num]
                        pdf_text += f"\n--- Page {page_num + 1} ---\n"
                        pdf_text += page.extract_text()
                    
                    file_text += pdf_text
                except Exception as e:
                    file_text += f"Error extracting PDF content: {str(e)}"
                
            message_content.append({"type": "text", "text": file_text})
    
    # Add the question text
    message_content.append({"type": "text", "text": question})
    
    # Stream the response
    with client.messages.stream(
        model=model,
        max_tokens=34000,
        messages=[{"role": "user", "content": message_content}],
        thinking=thinking_param,  # 👈 USE THE NEW VALUE HERE
    ) as stream:
        for event in stream:
            duration = round(time.time() - start_time, 2)

            if event.type == "content_block_delta":
                delta = event.delta
                print(f"⏳ Received delta at {duration}s: {delta}")
                if hasattr(delta, "text"):
                    text_data = f'data: {json.dumps({"type": "text", "text": delta.text})}\n\n'
                    print(f"📤 Sending text chunk at {duration}s")
                    yield text_data
                elif hasattr(delta, "thinking"):
                    # Log when thinking events are received and sent
                    thinking_data = f'data: {json.dumps({"type": "thinking", "thinking": delta.thinking, "timestamp": duration})}\n\n'
                    print(f"🧠 Sending thinking chunk at {duration}s: {delta.thinking[:50]}...")
                    yield thinking_data
