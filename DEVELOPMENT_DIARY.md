# Development Diary

I am developing this project with heavy AI support, trying to avoid implementing anything myself and trying to only guide the AI very toplevel from a manager point of view. Only in the End I want to actually review the code myself. Lets see how it goes!

I will try to document at least my toplevel-promts, documenting the ongoing prompts within one chat is too cumbersome and probably not necessary to understand the core strategies during development of this project.

## 2025-05-02

Initially I had asked the Agent within the rdf_core library to implement rdf/xml parser.

My initial promt in rdf_core was: 

```llm
Please implement both a parser and a serializer for rdf/xml
```

This prompt lead to non-compiling implementation and tests.

When it became clear that we need new dependencies for this, I decided to extract everything into a new project and let it fix everything it had created so far itself. I did the basic project extraction myself though.

My first promt in this project was:

```llm
This project implements a parser for rdf/xml format for rdf_core library. It was generated, but still contains a lot of compile errors. Can you go through the code, analyze it, analyze the rdf_core library for which it implements a RdfFormat and fix the code and tests?
```

## 2025-05-04

After some back and forth, it finally managed to answer this prompt and deliver compiling code where the tests run successfully.

Next step will be, to ask it to review the code in a new toplevel chat.