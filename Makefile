SHELL := /usr/bin/env bash

# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
#
# Params:
#   1. Variable name(s) to test.
#   2. (optional) Error message to print.
check_defined = \
	$(strip $(foreach 1,$1, \
		$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
	$(if $(value $1),, \
		$(error Undefined $1$(if $2, ($2))$(if $(value @), \
			required by target `$@')))

# apdf := asciidoctor-pdf -a pdf-stylesdir=./ -a pdf-style=custom -a imagesdir=./
apdf := asciidoctor-pdf -a pdf-stylesdir=./ -a imagesdir=./

uml := $(shell find . -type f -name "*.uml")
uml_svg := $(uml:.uml=.svg)
adoc_reports := $(shell find . -type f -name "*.adoc" ! -path "./locale/*" ! -path "./node_modules/*")
adoc_reports_pdf := $(adoc_reports:.adoc=.pdf)

default_aspell_lang := en_US
default_asciidoctor_lang := en

all: help

.PHONY: init
init: ## install dependencies
	yarn --pure-lockfile

.PHONY: build
build: ## build diagrams and reports
build: | build_uml build_adoc

.PHONY: clean
clean: ## delete generated diagrams, presentations and reports
	rm -f ${adoc_reports_pdf} ${uml_svg}

.PHONY: build_uml
build_uml: ## build diagrams
build_uml: ${uml_svg}

.PHONY: build_adoc
build_adoc: ## build reports
build_adoc: $(adoc_reports_pdf)

%.svg: %.uml
	plantuml -tsvg $<

%.pdf: $(uml_svg) %.adoc
	${apdf} -a lang=$(default_asciidoctor_lang) -o $@ \
		$(shell dirname $@)/$(shell basename -s .pdf $@).adoc

define spellcheck_adoc
  echo "spellchecking $1"
	test -f $1.lang && \
		aspell --conf=aspell.conf --encoding=utf-8 --home-dir=. --personal=aspell_dict_`cat $1.lang`.txt -d `cat $1.lang` -c $1 || \
		aspell --conf=aspell.conf --encoding=utf-8 --home-dir=. --personal=aspell_dict_$(default_aspell_lang).txt -d $(default_aspell_lang) -c $1;
endef

.PHONY: spellcheck
spellcheck: ## run aspell on all .adoc files
	$(foreach f,$(adoc_reports),$(call spellcheck_adoc,$(f)))

.PHONY: release
release: ## build release for document at {path} with {version}
	@:$(call check_defined, path, must point to the document root which should be released)
	@:$(call check_defined, version, must define the release version)
	@test -d "$(path)/.releases/$(version)" && { echo "Release exists already"; exit 1; } || true
	mkdir -p "$(path)/.releases/$(version)"
	ls -A1 $(adoc_reports_pdf) | grep "$(path)" | xargs rm
	cp -R "$(path)"/* "$(path)/.releases/$(version)/"
	find "$(path)/.releases/$(version)" -type f -name "*.adoc" -exec \
		sed -i "s|include::\.\./\.\./locale/attributes.adoc\[\]|include::../../../../locale/attributes.adoc[]|g" {} \;
	git add "$(path)/.releases/$(version)"
	git commit -m "New release: $(path) at v$(version)"
	@echo "Released version can be found at '$(path)/.releases/$(version)'"

watch: ## set up watch files and build them when changed
	find . -name "*.svg" -or -name "*.adoc" -or -name "*.uml" | entr -s 'make build'

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
