# Development Diary

I am developing this project with heavy AI support, trying to avoid implementing anything myself and trying to only guide the AI very toplevel from a manager point of view. Only in the End I want to actually review the code myself. Lets see how it goes!

I will try to document my toplevel-promts as well as my own follow-ups to show how the agent was instructed.

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

### Expert Review and Fixes (1)

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

This worked, code is back to running.

### Realworld testcases

Some "real" input from myself: I have brought a couple of real RDF documents and want them to be part of the tests. My toplevel propt is:

```llm
You are an experienced and very senior Software Test Engineer.

Please have a thorough look at this project and implement tests where you feel that there are tests missing.

I have put two rdf files in test/assets. Please implement a test for each one of those which loads the file, runs the parser and validates the result. Please also test that serializing back and deserializing again leads to the same result as the initial deserialization. The serialized forms may differ, which is fine.
```

This worked fine, the files are used in tests now and we did not have to adjust the code.

### Test Completeness

Ok, lets check for test completeness and ask for completion in a new toplevel chat.

```llm
You are an experienced and very senior Software Test Engineer.

Please have a thorough look at this project and implement tests where you feel that there are tests missing.
```

Hmm, that did not go 100% well. Tests fail and the reasoning of the LLM sounds fishy - my follow up:

```llm
1.) The tests do not run, you should have executed dart test.
2) Triples actually do implement the == operation correctly, no need for equals method.
3) I don't really understand your comments number 2 and three - The test should reflect what we want the system to act like, right? What do you mean with "Bei den Tests für Konfigurationsoptionen musste ich die Assertions so anpassen, dass sie auch dann bestehen, wenn die tatsächlichen Optionen anders implementiert sind als erwartet." and with "Bei den Fehlerbehandlungstest musste ich allgemeinere Assertion-Matchers verwenden (throwsException statt spezifischer Ausnahmetypen), da das tatsächliche Verhalten der Implementierung leicht abweichen kann"?
```

After this followup, tests run again and we assume all is good for now.

Based on this experience maybe a better initial prompt would have been something like:

```llm
You are an experienced and very senior Software Test Engineer. After implementing test you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the tests are passing.

You investigate the APIs you are using thoroughly and of course you stick to testing best practices: Tests should assert the expected behaviour. This includes asserting the expected exception classes etd. If tests fail, you first check if the test expectation is actually justified. If it is, then the implementation should be fixed to match the expected behavior, not the other way around. Only adjust the test if you come to the conclusion that its expectation was wrong.

Please have a thorough look at this project and implement tests where you feel that there are tests missing.
```

### Test Correctness

The experience of the last step leads me to want another Agent run, for making sure that the tests actually do make sense now.

Time for yet another toplevel chat:

```llm
You are an experienced and very senior Software Test Engineer. After implementing test you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the tests are passing.

You investigate the APIs you are using thoroughly and of course you stick to testing best practices: Tests should assert the expected behaviour. This includes asserting the expected exception classes etd. If tests fail, you first check if the test expectation is actually justified. If it is, then the implementation should be fixed to match the expected behavior, not the other way around. Only adjust the test if you come to the conclusion that its expectation was wrong.

Please have a thorough look at all tests implemented in this project and check if their expectations are legitimate or if they were adjusted to make tests pass where the implementation should have been fixed. If necessary, update existing tests (and/or add new ones) to make sure that the correct expectations are tested.
```

### Expert Review and Fixes (2)

Ok, we have improved both code and tests, lets ask the agent again to review the code in a new toplevel chat:

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

Please have a look at this codebase in lib and review it thoroughly. Come up with advice on what should be improved, if anything.
```

Interestingly, this did lead into a new round of changes, amongst others about performance improvements.

### Expert Review and Fixes (3)

Ok, check again if our senior software engineer is happy now (new toplevel).

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

Please have a look at this codebase in lib and review it thoroughly. Come up with advice on what should be improved, if anything. Is the codebase good enough to be released to the public as a world-class quality project?
```

While the agent stated he was happy with the codebase to be released, it still had some important advices. So we will definitely ask again after the next step.

### Documentation

Now it is time to revisit our documentation.

```llm
You are a top-notch writer of technical documentation and you want this project to be a world-class project that meets the highest standards of excellence.

Please first read the sourcecode in this project to make sure you understand what it is about from a toplevel point of view. Then go through all files and mnake sure they are documented to the highest standards:

* language is english 
* document the why, not the what
* target audience are Dart developers who may not be very familiar with the specifics of the problem this project solves (e.g. with rdf/xml format)

After fixing the sourcecode documentation, please create a really helpful and useful README. Note: this project will be on github and deployed to pub.dev.

In addition, also create a really great and modern landingpage in doc/ directory, which also includes  links to the api documentation which you generate by calling `dart doc -o doc/api .`
```

Follow Up:

```llm
Yes, please implement each of your suggestions one by one.
```

Wow, this did  a lot of changes, but lets wait until the very end to actually review the result.

### Expert Review - Final (?) Quality Checks

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. 

You value clean, very readable code and will not accept code that "does too much" and thus is hard to read and understand. You also do not like hardcoded or duplicate code - if functionality is available in one of the used libraries, you strongly prefer to use that one instead of duplicating or hardcoding it. If necessary, you go to the documentation and code to improve your knowledge and understanding of available functionality.

You also always read the documentation and comments and make sure that all examples provided make sense and are using correct syntax and are not hallucinated.

When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

Please have a look at this codebase in lib and review it thoroughly. Come up with advice on what should be improved, if anything. Is the codebase good enough to be released to the public as a world-class quality project?
```

Ok, it still has some points that sounds as if we should adhere to its advice, so lets go:

```llm
Yes, please implement each of your suggestions one by one.
```

Follow up

```llm
Thanks. Unfortunately, this broke compilation. Please execute `dart analyze` to find out what the compile errors are and analyze what you have to do in order to fix them. Wrong API usage? Missing Imports? Missing Code?

When code and tests compile, please run the tests and make sure that all will pass.
```

Follow up (when asked if the remaining problems should be solved)

```llm
yes
```

Again, the agent said that there were warnings and asked if it should resolve them..

```llm
yes
```

Ok, unused imports, let it clean up those as well

```llm
yes
```

Ok wow - that were many changes. We should probably do another full round of asking the technical writer and the test engineer. And we need to improve the senior engineer prompt apparently...

### Test Correctness (2)

Time for yet another toplevel chat:

```llm
You are an experienced and very senior Software Test Engineer. After implementing test you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the tests are passing.

You investigate the APIs you are using thoroughly and of course you stick to testing best practices: Tests should assert the expected behaviour. This includes asserting the expected exception classes etd. If tests fail, you first check if the test expectation is actually justified. If it is, then the implementation should be fixed to match the expected behavior, not the other way around. Only adjust the test if you come to the conclusion that its expectation was wrong.

Please have a thorough look at all tests implemented in this project and check if their expectations are legitimate or if they were adjusted to make tests pass where the implementation should have been fixed. If necessary, update existing tests (and/or add new ones) to make sure that the correct expectations are tested. Also check if there are important tests missing and add them if needed.
```

Looks good, but has compile errors - need to check again.

```llm
Thanks. Unfortunately, this broke compilation. Please execute `dart analyze` to find out what the compile errors are and analyze what you have to do in order to fix them. Wrong API usage? Missing Imports? Missing Code?

When code and tests compile, please run the tests and make sure that all will pass.
```

I had to interrupt because it failed with a non-helpful error that lead the agent into a wrong direction. In addition, I had to interrupt again because it was relaxing a test for the wrong reasons and then it even added code to hardcode to '<http://example.org>' in order to make the tests pass.

Actually, it went into some sort of endless loop, incapable of fixing the issues.

---

### RESET

---

Unfortunately it all ended up as one big mess, so I had to revert and restart the test part.

So we need to adjust our tester prompt again. This time we use:

```llm
You are an experienced and very senior Software Test Engineer. After implementing test you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the tests are passing. 

You investigate the APIs you are using thoroughly and of course you stick to testing best practices: Tests should assert the expected behaviour. This includes asserting the expected exception classes etd. If tests fail, you first check if the test expectation is actually justified. If it is, then the implementation must be fixed to match the expected behavior, not the other way around. Only adjust the test if you come to the conclusion that its expectation was wrong. You are part of the team implementing this code and your goal is to find errors in the implementation, not to write tests that match the implementation and that only fails if the implementation is changed.

When you adjust the code, you strive to fix the underlying problem correctly and you never introduce test-specific hacks or constants that only exist to make the tests pass. Instead, you analyze the problem deeply and then solve it properly.

You value clean, idiomatic and readable code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. 

You do not like hardcoded or duplicate code - if functionality is available in one of the used libraries, you strongly prefer to use that one instead of duplicating or hardcoding it. If necessary, you go to the documentation and code to improve your knowledge and understanding of available functionality.

Please have a thorough look at all tests implemented in this project and check if their expectations are legitimate or if they were adjusted to make tests pass where the implementation should have been fixed. If necessary, update existing tests (and/or add new ones) to make sure that the correct expectations are tested. Also check if there are important tests missing and add them if needed.
```

TODO:

* Add test for streaming of real world files, verify that the result is exactly the same as non-streaming
* What about Bag, Set, Alt? Is it handled correctly in streaming and non-streaming?

---

### RESET (2)

---

Again it all ended up as one big mess, so I had to revert and restart the test part. It started off really promising, but then it lost itself.

So we need to adjust our tester prompt again. This time we use:

```llm
You are an experienced and very senior Software Test Engineer. After implementing test you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the tests are passing. 

You investigate the APIs you are using thoroughly and of course you stick to testing best practices: Tests should assert the expected behaviour. This includes asserting the expected exception classes etc. If tests fail, you first check if the test expectation is actually justified. If it is, then the implementation must be fixed to match the expected behavior, not the other way around. Only adjust the test if you come to the conclusion that its expectation was wrong. You are part of the team implementing this code and your goal is to find errors in the implementation, not to write tests that match the implementation and that only fails if the implementation is changed. DO NOT actually adjust the code - leave this for the experts. Your job is, to create great test cases that show what works and what does not work as it should.

Please have a thorough look at all tests implemented in this project and check if their expectations are legitimate or if they were adjusted to make tests pass where the implementation should have been fixed. If necessary, update existing tests (and/or add new ones) to make sure that the correct expectations are tested. Also check if there are important tests missing and add them if needed.

Please add missing tests.
```

TODO:

* Add test for streaming of real world files, verify that the result is exactly the same as non-streaming
* What about Bag, Set, Alt? Is it handled correctly in streaming and non-streaming?

Ok, after executing this, we will need to ask again for fixes in a new toplevel chat::

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. 

You value clean, very readable code and will not accept code that "does too much" and thus is hard to read and understand. You also do not like hardcoded or duplicate code - if functionality is available in one of the used libraries, you strongly prefer to use that one instead of duplicating or hardcoding it. If necessary, you go to the documentation and code to improve your knowledge and understanding of available functionality.

You also always read the documentation and comments and make sure that all examples provided make sense and are using correct syntax and are not hallucinated.

When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

After implementing code or tests you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the code is compiling and that the tests are passing.

Please execute the tests in this project with `dart test`. There are quite a few failing tests. Please fix each failing test by fixing the code. Only change the test if you do find out that the expectation in the test is actually really wrong. 
```

TODO:

* stream_parsing.dart has a hardcoded map of namespaces. This is bad. If those standard namespaces are intended, we should pass in the RdfNamespaceMappings class

---

## 2025-05-05

after some "continue" follow ups of the last prompt, the agent finished eventually, but still there are only 59/75 passing tests.

Seems like I need to get involved more now. Lets start with the namespaces hardcoding. After fixing the namespace stuff, lets re-rexecute the developer agent and let it try again to fix issues.

Ok - I stopped the support for streaming. This is something that apparently is too difficult for the Agent and I do not really need it at the moment. It was a (sensible) suggestion of the agent, but the code got
messier and messier, so I removed it alltogether now.

### TODO: Documentation (2)

Now it is time to revisit our documentation again.

```llm
You are a top-notch writer of technical documentation and you want this project to be a world-class project that meets the highest standards of excellence.

Please first read the sourcecode in this project to make sure you understand what it is about from a toplevel point of view. Then go through all files and mnake sure they are documented to the highest standards, including but not limited to the following criteria:

* code and documentation language is english 
* document the why, not the what
* target audience are Dart developers who may not be very familiar with the specifics of the problem this project solves (e.g. with rdf/xml format)

Now that you have a good understanding of the project, please make sure that we have really usefull examples in the example directory. Run `dart analyze` to make sure that they are running and execute them with `dart run` to make sure that they output what you expect them to output.

After fixing the sourcecode documentation, please make sure that the README is really helpful and useful. Note: this project will be on github and deployed to pub.dev. Take care to validate that all examples in the README actually are valid and only use existing APIs - maybe you should only use examples that you already have in the example directory?

In addition, also update if neccessary our really great and modern landingpage in doc/ directory, which also includes  links to the api documentation which you can generate by calling `dart doc -o doc/api .`. The documentation in doc of course also should only contain examples where you are sure that they are correct and use existing APIs (maybe by putting them in the example directory if they are not there yet).
```

TODO

* only serialize namespaces that are actually used
* check that examples run  correctly

### TODO: Expert Review - Final (?) Quality Checks v2

```llm
You are a very experienced senior dart developer who values clean and idiomatic code. You have a very good sense for clean architecture and stick to best practices and well known principles like KISS, SOLID, Inversion of Control (IoC) etc. You know that hardcoded special cases and in general code that is considered a "hack" or "code smell" are very bad and you are brilliant in coming up with excelent, clean alternatives. 

You value clean, very readable code and will not accept code that "does too much" and thus is hard to read and understand. You also do not like hardcoded or duplicate code - if functionality is available in one of the used libraries, you strongly prefer to use that one instead of duplicating or hardcoding it. If necessary, you go to the documentation and code to improve your knowledge and understanding of available functionality.

You also always read the documentation and comments and make sure that all examples provided make sense and are using correct syntax and are not hallucinated.

When reviewing code, you look out not only for all of those and you strive for highest quality. You always strive to understand the context of the code as well and avoid over-engineering. 

After implementing code or tests you of course execute `dart analyze`, `dart format` etc and of course `dart test` to verify that the code is compiling and that the tests are passing.

Please have a look at this codebase in lib and review it thoroughly. Come up with advice on what should be improved, if anything. Is the codebase good enough to be released to the public as a world-class quality project?
```

### TODO: Potential User Review

```llm
You are a dart developer working on a project where you think that RDF would be useful and you have a preference (or need for other reasons) to choose XML for (de)serialization of RDF. 

You come across our library on pub.dev and read the README.md and the docs underneath doc. 

What do you think of this library? Do you want to use it?
```

### Ready for human feedback?
