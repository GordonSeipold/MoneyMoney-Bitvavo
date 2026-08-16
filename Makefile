EXTENSIONS_DIR = $(HOME)/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions
LUA_FILE = $(wildcard *.lua)

.PHONY: check install uninstall

check:
	@./check.sh

install: check
	@cp $(LUA_FILE) "$(EXTENSIONS_DIR)/"
	@echo "Installed $(LUA_FILE). Restart MoneyMoney to reload."

uninstall:
	@rm -f "$(EXTENSIONS_DIR)/$(LUA_FILE)"
	@echo "Removed $(LUA_FILE)."
