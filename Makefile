all: docs

docs:
	pandoc docs/DEPLOYMENT.md -o docs/DEPLOYMENT.pdf --pdf-engine=xelatex -V geometry:margin=1in -V fontsize=11pt
	@echo "✅ docs/DEPLOYMENT.pdf regenerated"

clean:
	rm -f docs/DEPLOYMENT.pdf
	@echo "🧹 Cleaned generated files"
