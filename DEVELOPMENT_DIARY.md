# Development Diary

I am developing this project with heavy AI support, trying to avoid implementing anything myself and trying to only guide the AI very toplevel from a manager point of view. Only in the End I want to actually review the code myself. Lets see how it goes!

I will try to document at least my toplevel-promts, documenting the ongoing prompts within one chat is too cumbersome and probably not necessary to understand the core strategies during development of this project.

I am using VSCode Copilot Agent with Claude 3.7 Sonnet

## 2025-05-02

Initially I had asked the Agent within the rdf_core library to implement rdf/xml parser.

### Initial Promt for rdf_xml

My initial toplevel promt in rdf_core was: 

```llm
Please implement both a parser and a serializer for rdf/xml
```

This prompt lead to non-compiling implementation and tests.

When it became clear that we need new dependencies for this, I decided to extract everything into a new project and let it fix everything it had created so far itself. I did the basic project extraction myself though.

### Fix Errors Prompt 1

My first toplevel promt in this project was:

```llm
This project implements a parser for rdf/xml format for rdf_core library. It was generated, but still contains a lot of compile errors. Can you go through the code, analyze it, analyze the rdf_core library for which it implements a RdfFormat and fix the code and tests?
```

Follow up:

```llm
danke - leider kompiliert es immer noch nicht. Analysier das bitte noch einmal und löse das Problem.
```

Follow up:

```llm
Es gibt weiterhin compile fehler. Bitte führe doch "dart analyze" aus und schaue was das problem ist. Behebe bitte die Fehler in code und tests. Ausserdem bitte "dart test" ausführen wenn alles kompiliert und die Testfehler behebem.
```

Follow up:

```llm
Ich habe eben kurz geschaut, und denke dass das Problem vor allem an der Verwendung von RdfPredicates liegt - diese Klasse ist kein Bestandteil der Api von rdf_core und wird es auch nicht sein. Definiere dir bitte Konstanten selber wenn du sie benötigst.
```

Follow up:

```llm
schaue dir die Api von RdfGraph vielleicht nochmal genauer an: es ist eine immutable Klasse. Am Besten werden die Triples im Konstruktor übergeben - RdfGraph(triples: triples). Wenn das nicht geht, kann man auch withTriples oder withTriple verwenden, was beides eine neue Instanz erzeugt.
```

Follow up:

```llm
Why is _resolveQName in rdfxml_parser.dart not used? If we do not need it and do not need _namespaceMappings, why don't you remove it?
```

## 2025-05-04

After some back and forth, it finally managed to answer this prompt and deliver compiling code where the tests run successfully.

Next step will be, to ask it to review the code in a new toplevel chat:

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

Please have a look at this codebase in lib and review it thoroughly. Come up with advice on what should be improved.
```

Follow up:

```llm
Please go through your own suggestions for improvements and implement each one, one after the other.
```

Follow up:

```llm
Thanks. Unfortunately, this broke compilation. Please execute `dart analyze` to find out what the compile errors are and analyze what you have to do in order to fix them. Wrong API usage? Missing Imports? Missing Code?

When code and tests compile, please run the tests and make sure that all will pass.
```