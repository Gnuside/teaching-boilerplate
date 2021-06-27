#!/usr/bin/make -f

## Configure this part if you wish to
DEPLOY_REPO=
DEPLOY_OPTS=

## Input directories
SLIDES_DIR=slides
DOCS_DIR=docs
IMAGES_DIR=images
BUILD_DIR=_build

## Output directories
BUILD_SLIDES_DIR=$(BUILD_DIR)/slides
BUILD_DOCS_DIR=$(BUILD_DIR)/docs
BUILD_IMAGES_DIR=images

## Ports
DOCS_PORT=5100
SLIDES_PORT=5200

## Find .md slides
SLIDES_MD=$(shell find $(SLIDES_DIR) \( -name '*.md' ! -name '_*' \))
SLIDES_PDF=$(patsubst $(SLIDES_DIR)/%.md,$(BUILD_SLIDES_DIR)/%.pdf,$(SLIDES_MD))

## Find .uml graphs
DOCS_IMAGES_UML=$(shell find $(IMAGES_DIR) \( -name '*.uml' ! -name '_*' \))
DOCS_IMAGES_UML_SVG=$(patsubst $(IMAGES_DIR)/%.uml,$(BUILD_IMAGES_DIR)/%.uml.svg,$(DOCS_IMAGES_UML))

## Find .dot graphs
DOCS_IMAGES_DOT=$(shell find $(IMAGES_DIR) \( -name '*.dot' ! -name '_*' \))
DOCS_IMAGES_DOT_SVG=$(patsubst $(IMAGES_DIR)/%.dot,$(BUILD_IMAGES_DIR)/%.dot.svg,$(DOCS_IMAGES_DOT))

## Find .circo graphs
DOCS_IMAGES_CIRCO=$(shell find $(IMAGES_DIR) \( -name '*.circo' ! -name '_*' \))
DOCS_IMAGES_CIRCO_SVG=$(patsubst $(IMAGES_DIR)/%.circo,$(BUILD_IMAGES_DIR)/%.circo.svg,$(DOCS_IMAGES_CIRCO))

## Find .ora images
DOCS_IMAGES_ORA=$(shell find $(IMAGES_DIR) \( -name '*.ora' ! -name '_*' \))
DOCS_IMAGES_ORA_PNG=$(patsubst $(IMAGES_DIR)/%.ora,$(BUILD_IMAGES_DIR)/%.ora.png,$(DOCS_IMAGES_ORA))

## Merge all lists
DOCS_IMAGES_SVG=$(DOCS_IMAGES_DOT_SVG) $(DOCS_IMAGES_CIRCO_SVG) $(DOCS_IMAGES_UML_SVG)
DOCS_IMAGES_PNG=$(DOCS_IMAGES_ORA_PNG)

all: help

##
## Install prerequisites
##

prepare: prepare-slides prepare-docs ## install prerequisites

prepare-slides: ## install prerequisites for PDF slides only
	npm install
	npx browserslist@latest --update-db

prepare-docs: ## install prerequisites for static docs site only
	pipenv install

.PHONY: prepare prepare-slides prepare-docs

images: $(DOCS_IMAGES_SVG) $(DOCS_IMAGES_PNG) ## build images
	@echo "Source:"
	@echo "  ora: $(DOCS_IMAGES_ORA)"
	@echo "  uml: $(DOCS_IMAGES_UML)"
	@echo "  dot: $(DOCS_IMAGES_DOT)"
	@echo "  circo: $(DOCS_IMAGES_CIRCO)"
	@echo "Built: $(DOCS_IMAGES_SVG) $(DOCS_IMAGES_PNG)"

.PHONY: images

%.ora.png: %.ora
	TMPDIR="$$(mktemp -d)" \
		&& unzip -q $< -d "$$TMPDIR" mergedimage.png \
		&& touch "$$TMPDIR/mergedimage.png" \
		&& mv "$$TMPDIR/mergedimage.png" $@

%.uml.svg: %.uml
	plantuml -pipe -tsvg < $< > $@

%.dot.svg: %.dot
	dot -Tsvg $< > $@

%.circo.svg: %.circo
	circo -Tsvg $< > $@

.marp/theme.css:
	cd .marp && $(MAKE) theme.css

watch: ## run development server
	pipenv run honcho start 

watch-tocupdate-internal:
	while inotifywait -q -e move -e modify -e create -e attrib -e delete -e moved_to -r docs ; do \
		sleep 2 ; \
		$(MAKE) images ; \
		$(MAKE) tocupdate ; \
	done

watch-docs-internal:
	pipenv run mkdocs serve --dev-addr 0.0.0.0:$(DOCS_PORT)

watch-slides-internal: .marp/theme.css
	PORT=$(SLIDES_PORT) \
		 npx marp \
		 --engine $$(pwd)/.marp/engine.js \
		 --html \
		 --theme $$(pwd)/.marp/theme.css \
		 -w $(SLIDES_DIR) \
		 -s

watch-slides: ## run development server for PDF slides
	pipenv run honcho start slides

watch-docs: ## run development server for static docs site
	pipenv run honcho start docs toc

serve: watch
serve-slides: watch-slides
serve-docs: watch-docs

.PHONY: watch watch-slides watch-docs watch-slides-internal watch-docs-internal serve serve-docs serve-slides


tocupdate:
	pipenv run ./scripts/update-toc $(DOCS_DIR) ; \


$(BUILD_SLIDES_DIR)/%.pdf: $(SLIDES_DIR)/%.md
	mkdir -p $(BUILD_SLIDES_DIR)
	npx marp --allow-local-files \
	 	 --engine $$(pwd)/.marp/engine.js \
	 	 --html \
	 	 --theme $$(pwd)/.marp/theme.css \
	 	 $< \
	 	 -o $@


##
## Build final documents 
##
## slides => PDF
## docs   => static web site
##

build: build-docs build-slides ## build all documents

build-slides: $(SLIDES_PDF) $(SLIDES_MD) ## build PDF slides only

build-docs: ## build static docs site only
	$(MAKE) tocupdate
	mkdir -p $(BUILD_DOCS_DIR)
	pipenv run mkdocs build \
		--site-dir $(BUILD_DOCS_DIR)

.PHONY: build build-slides

deploy-docs: ## deploy static docs site to github
	git push $(DEPLOY_REPO)
	pipenv run mkdocs gh-deploy $(DEPLOY_OPTS)

help: ## print this help
	@echo "Usage: make <target>"
	@echo ""
	@echo "With one of following targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} \
	  /^[a-zA-Z_-]+:.*?## / \
	  { sub("\\\\n",sprintf("\n%22c"," "), $$2); \
		printf("\033[36m%-20s\033[0m %s\n", $$1, $$2); \
	  }' $(MAKEFILE_LIST)
	@echo ""


##
## Clean
##

clean: clean-slides clean-docs # remove generated documents

clean-slides:
	rm -fr $(BUILD_SLIDES_DIR) # remove generated PDF slides

clean-docs:
	rm -fr $(BUILD_DOCS_DIR) # remove generated static docs site

.PHONY: clean clean-slides clean-docs

##
## Utilities
##

fixme:
	@egrep --color -rni '(fixme)' $(DOCS_DIR) $(SLIDES_DIR)

.PHONY: fixme
