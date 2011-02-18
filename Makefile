PROGRAM=./build/Release/markdown

all : $(PROGRAM)

$(PROGRAM):
	xcodebuild

.PHONY: clean test

clean:
	xcodebuild clean

test: $(PROGRAM)
	cd MarkdownTest_1.0.3; \
	./MarkdownTest.pl --script=../$(PROGRAM) --tidy

leak-check: $(PROGRAM)
	valgrind --leak-check=full ./markdown README

