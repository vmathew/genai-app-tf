import streamlit as st
from langchain.llms import Bedrock
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain_community.callbacks import StreamlitCallbackHandler

# Initialize Bedrock LLM
llm = Bedrock(
    model_id="amazon.titan-text-express-v1",
    client_kwargs={"region_name": "us-east-1"},  # Replace with your preferred region
)

# Create a prompt template
prompt = PromptTemplate(
    input_variables=["question"],
    template="Answer the following question: {question}"
)

# Create an LLMChain
chain = LLMChain(llm=llm, prompt=prompt)

# Streamlit app
st.title("Amazon Titan Text G1 - Express LLM Demo")

# User input
user_question = st.text_input("Enter your question:")

if user_question:
    # Create a Streamlit container for the response
    response_container = st.container()
    
    # Generate response
    with response_container:
        st_callback = StreamlitCallbackHandler(st.container())
        response = chain.run(question=user_question, callbacks=[st_callback])
        st.write("Final Answer:", response)