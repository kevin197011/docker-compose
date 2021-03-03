all: pull p
.PHONY: pull p

pull:
	git pull

p:
	git add .
	git commit -m "Update."
	git push origin master