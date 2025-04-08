from langchain_core.tools import Tool
from langchain.chains.llm import LLMChain
from langchain_core.prompts import PromptTemplate
from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.outputs import ChatGeneration, ChatResult
from typing import List, Dict, Any, Optional
import os
import json
from litellm import completion
from pydantic import Field

# Load API key from config.json
with open('config.json', 'r') as f:
    config = json.load(f)
    CLAUDE_API_KEY = config['openai']['claude_key']

class LiteLLMChatModel(BaseChatModel):
    """Chat model that uses LiteLLM proxy to call Claude models."""
    
    model_name: str = Field(default="claude-3-7-sonnet-latest")
    temperature: float = Field(default=0.7)
    api_base: str = Field(default="https://ipsos.litellm-prod.ai")
    api_key: str = Field(default=CLAUDE_API_KEY)
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    @property
    def _llm_type(self) -> str:
        """Return type of LLM."""
        return "litellm-chat"
    
    def _generate(self, messages, stop=None, run_manager=None, **kwargs):
        # Convert LangChain messages to LiteLLM format
        litellm_messages = []
        for message in messages:
            if isinstance(message, SystemMessage):
                litellm_messages.append({"role": "system", "content": message.content})
            elif isinstance(message, HumanMessage):
                litellm_messages.append({"role": "user", "content": message.content})
            else:
                litellm_messages.append({"role": "assistant", "content": message.content})
        
        # Call LiteLLM
        response = completion(
            model=self.model_name,
            messages=litellm_messages,
            temperature=self.temperature,
            api_base=self.api_base,
            api_key=self.api_key,
            **kwargs
        )
        
        # Convert response back to LangChain format
        message = AIMessage(content=response.choices[0].message.content)
        generation = ChatGeneration(message=message)
        return ChatResult(generations=[generation])

def create_thought_loop_chain():
    prompt = PromptTemplate.from_template("""
    You are a thoughtful assistant. Think step by step before answering.
    
    Question: {question}
    
    Thought:""")
    
    llm = LiteLLMChatModel(model_name="claude-3-7-sonnet-latest", temperature=0.7)
    
    return LLMChain(prompt=prompt, llm=llm)
