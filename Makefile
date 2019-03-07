# In case your system doesn't have any of these tools:
# https://pypi.python.org/pypi/xml2rfc
# https://github.com/Juniper/libslax/tree/master/doc/oxtradoc

draft = draft-ietf-netmod-yang-data-ext.org
output_base = draft-ietf-netmod-yang-data-ext
examples =
trees =
std_yang =
ex_yang =
references_src = references.txt
references_xml = references.xml

# ----------------------------
# Shouldn't need to modify anything below this line

ifeq (,$(draft))
possible_drafts = draft-*.xml draft-*.md draft-*.org
draft := $(lastword $(sort $(wildcard ${possible_drafts})))
endif

draft_base = $(basename ${draft})
draft_type := $(suffix ${draft})

ifeq (,${examples})
examples = $(wildcard ex-*.xml)
endif
load=$(patsubst ex-%.xml,ex-%.load,$(examples))

ifeq (,${std_yang})
std_yang := $(wildcard ietf*.yang)
endif
ifeq (,${ex_yang})
ex_yang := $(wildcard ex*.yang)
tmp_ex_yang=$(patsubst %.yang,tmp/%.yang,$(ex_yang))
endif
yang := $(std_yang) $(ex_yang)

xml2rfc ?= xml2rfc
oxtradoc ?= oxtradoc
idnits ?= idnits
pyang ?= pyang

ifeq (,$(draft))
$(warning No file named draft-*.md or draft-*.xml or draft-*.org)
$(error Read README.md for setup instructions)
endif

current_ver := $(shell git tag | grep '${output_base}-[0-9][0-9]' | tail -1 | sed -e"s/.*-//")
ifeq "${current_ver}" ""
next_ver ?= 00
else
next_ver ?= $(shell printf "%.2d" $$((1$(current_ver)-99)))
endif
output = ${output_base}-${next_ver}

.PHONY: latest submit clean validate

submit: ${output}.txt

html: ${output}.html

latest: ${output}.txt

idnits: ${output}.txt
	$(idnits) $<

clean:
	-rm -f ${output_base}-[0-9][0-9].* ${references_xml} $(load)
	-rm -rf *.dsrl *.rng *.sch ${draft_base}.fxml tmp

# won't be auto removed, use make clean :(
# we use this temporarily to do fake-validation of the
# example, since pyang can't validate sx:structure yet.
tmp:
	mkdir tmp

tmp/%.yang: %.yang tmp
	sed -e 's/sx:structure/container/' \
	    -e 's/sx:augment-structure/augment/' < $< > $@
.INTERMEDIATE: $(tmp_ex_yang)

%.load: %.xml
	cat $< | awk -f fix-load-xml.awk > $@
.INTERMEDIATE: $(load)

example-system.oper.yang: example-system.yang
	grep -v must $< > $@
.INTERMEDIATE: example-system.oper.yang

validate: validate-std-yang validate-ex-yang validate-ex-xml

validate-std-yang: $(std_yang)
	pyang --ietf --max-line-length 69 $(std_yang)

ifneq (,${ex_yang})
validate-ex-yang: $(ex_yang)
	pyang --canonical --max-line-length 69 $(ex_yang)
else
validate-ex-yang:
endif

validate-ex-xml: $(std_yang) $(tmp_ex_yang) ex-address-book.xml
	yang2dsdl -j -x -t data -v ex-address-book.xml $(tmp_ex_yang)

${references_xml}: ${references_src}
	$(oxtradoc) -m mkback $< > $@

${output}.xml: ${draft} ${references_xml} $(trees) $(load) $(yang)
	$(oxtradoc) -m outline-to-xml -n "${output}" $< > $@

${output}.txt: ${output}.xml
	$(xml2rfc) $< -o $@ --text

%.tree: %.yang
	$(pyang) -f tree --tree-line-length 68 $< > $@

${output}.html: ${draft} ${references_xml} $(trees) $(load) $(yang)
	@echo "Generating $@ ..."
	$(oxtradoc) -m html -n "${output}" $< > $@
