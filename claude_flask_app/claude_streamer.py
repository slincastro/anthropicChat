from litellm import completion
import os
import json
import os
import time
import json
from anthropic import Anthropic
from anthropic.types import MessageStreamEvent


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
    extended_thinking: bool = False,
    thinking_tokens: int = 1024,  
    model: str = "claude-3-7-sonnet-latest"
):
    start_time = time.time()
    print(f"🧠 Using extended thinking: {extended_thinking} with {thinking_tokens} tokens")

    thinking_param = (
        {"type": "enabled", "budget_tokens": thinking_tokens}
        if extended_thinking else None
    )

    with client.messages.stream(
        model=model,
        max_tokens=34000,
        messages=[{"role": "user", "content": question}],
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
