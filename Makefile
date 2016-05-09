PUBDIR:=publish
BINDIR:=bin
MAINLUA:=bump.lua
MAINLUADST:=$(PUBDIR)/main.lua
LOVEGAME:=bump.love

EVERTHING:=$(wildcard *.* */*.* */*/*.* */*/*/*.* */*/*/*/*.*)
EVERTHING:=$(filter-out $(PUBDIR) $(PUBDIR)/% $(MAINLUA) $(LOVEGAME), $(EVERTHING))
EVERTHINGOUT:=$(addprefix $(PUBDIR)/, $(EVERTHING))

all: $(MAINLUADST) $(EVERTHINGOUT) $(LOVEGAME)

clean:
	rm -rf $(LOVEGAME) $(LOVEGAMEEXE) $(LOVEGAMEEXESTANDALONE)
	rm -rf ./$(PUBDIR)/*

run:
	love $(LOVEGAME)

$(PUBDIR)/%: %
	mkdir -p $(@D); cp $< $@

$(MAINLUADST): $(MAINLUA)
	mkdir -p $(@D); cp $< $@

$(LOVEGAME): $(EVERTHINGOUT)
	cd $(PUBDIR) && zip -9 -q -r ../$(LOVEGAME) .
