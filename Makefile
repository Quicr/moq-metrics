
# install xml2rfc with "pip install xml2rfc"
# install mmark from https://github.com/mmarkdown/mmark 
# install pandoc from https://pandoc.org/installing.html
# install lib/rr.war from https://bottlecaps.de/rr/ui or https://github.com/GuntherRademacher/rr

.PHONE: all clean lint format

all: gen/draft-jennings-moq-metrics.txt

html: gen/draft-jennings-moq-metrics.html

clean:
	rm -rf gen/*

lint: gen/draft-jennings-moq-metrics.xml
	rfclint gen/draft-jennings-moq-metrics.xml

gen/draft-jennings-moq-metrics.xml: draft-jennings-moq-metrics.md
	mkdir -p gen
	mmark  draft-jennings-moq-metrics.md > gen/draft-jennings-moq-metrics.xml

gen/draft-jennings-moq-metrics.txt: gen/draft-jennings-moq-metrics.xml
	xml2rfc --text --v3 gen/draft-jennings-moq-metrics.xml

gen/draft-jennings-moq-metrics.pdf: gen/draft-jennings-moq-metrics.xml
	xml2rfc --pdf --v3 gen/draft-jennings-moq-metrics.xml

gen/draft-jennings-moq-metrics.html: gen/draft-jennings-moq-metrics.xml
	xml2rfc --html --v3 gen/draft-jennings-moq-metrics.xml

gen/doc-jennings-moq-metrics.pdf: title.md abstract.md introduction.md naming.md metricscol.md manifest.md relay.md contributors.md
	mkdir -p gen 
	pandoc -s draft-jennings-moq-metrics.md -o gen/doc-jennings-moq-metrics.pdf

