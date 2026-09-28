#!/usr/bin/env python3
"""Gera as listas do Wordle (docs/PLANO_WORDLE_SENHA.md §7).

  palpites.txt  todas as palavras de 5 letras do VERO (dicionário pt-BR do LibreOffice, LGPLv3/MPL),
                expandidas com as flexões (plural, feminino, verbos conjugados), uma por linha, com acento.
  candidatas    (só com --candidatas) formas-base de 5 letras ordenadas por frequência, pra escolher
                as respostas à mão. A lista final de respostas é games/wordle/data/respostas.txt,
                curada e revisada por gente; este script só confere que toda resposta é um palpite.

Uso: tools/build_wordle_words.py [--candidatas arquivo_de_frequencia]
O VERO é baixado pra build/vero/ na primeira vez.
"""
import os
import re
import sys
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "build", "vero")
DATA = os.path.join(ROOT, "games", "wordle", "data")
BASE_URL = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/pt_BR/"
LETTERS = re.compile(r"^[a-zà-ÿ]+$")


def norm(w):
	w = unicodedata.normalize("NFD", w.lower())
	return "".join(c for c in w if unicodedata.category(c) != "Mn")


def fetch(name):
	os.makedirs(CACHE, exist_ok=True)
	path = os.path.join(CACHE, name)
	if not os.path.exists(path):
		urllib.request.urlretrieve(BASE_URL + name, path)
	return path


def read_aff(path):
	rules = {}  # flag -> (tipo, cruza, [(tira, põe, flags de continuação, regex)])
	with open(path, encoding="utf-8-sig") as f:
		lines = f.read().splitlines()
	for ln in lines:
		p = ln.split()
		if len(p) < 4 or p[0] not in ("SFX", "PFX"):
			continue
		kind, flag = p[0], p[1]
		if flag not in rules and p[2] in ("Y", "N") and len(p) == 4:
			rules[flag] = (kind, p[2] == "Y", [])
			continue
		if flag not in rules or len(p) < 5:
			continue
		strip = "" if p[2] == "0" else p[2]
		add, _, cont = p[3].partition("/")
		add = "" if add == "0" else add
		cond = p[4]
		rx = re.compile((cond + "$") if kind == "SFX" else ("^" + cond)) if cond != "." else None
		rules[flag][2].append((strip, add, cont, rx))
	return rules


def apply(rules, word, flags, depth=0):
	out = set()
	for fl in flags:
		if fl not in rules:
			continue
		kind, cross, entries = rules[fl]
		for strip, add, cont, rx in entries:
			if rx and not rx.search(word):
				continue
			if kind == "SFX":
				if strip and not word.endswith(strip):
					continue
				nw = (word[: len(word) - len(strip)] if strip else word) + add
			else:
				if strip and not word.startswith(strip):
					continue
				nw = add + word[len(strip):]
			out.add(nw)
			if cont and depth == 0:
				out |= apply(rules, nw, list(cont), 1)
	return out


def main():
	rules = read_aff(fetch("pt_BR.aff"))
	stems = {}
	forms = set()
	with open(fetch("pt_BR.dic"), encoding="utf-8-sig") as f:
		next(f)
		for ln in f:
			ln = ln.strip()
			if not ln:
				continue
			word, _, flags = ln.partition("/")
			if not LETTERS.match(word):
				continue  # nomes próprios, siglas, palavras compostas
			forms.add(word)
			forms |= apply(rules, word, list(flags))
			stems[word] = flags
	five = sorted({w for w in forms if LETTERS.match(w) and len(norm(w)) == 5 and len(w) == 5})
	with open(os.path.join(DATA, "palpites.txt"), "w", encoding="utf-8") as f:
		f.write("\n".join(five) + "\n")
	print(f"{len(five)} palpites")
	answers_path = os.path.join(DATA, "respostas.txt")
	if os.path.exists(answers_path):
		ok = {norm(w) for w in five}
		answers = [a.strip() for a in open(answers_path, encoding="utf-8") if a.strip() and not a.startswith("#")]
		missing = [a for a in answers if norm(a) not in ok]
		print(f"{len(answers)} respostas; fora dos palpites: {missing or 'nenhuma'}")
	if "--candidatas" in sys.argv:
		freq = {}
		with open(sys.argv[sys.argv.index("--candidatas") + 1], encoding="utf-8") as f:
			for i, ln in enumerate(f):
				freq.setdefault(ln.split()[0], i)
		cands = [w for w in stems if len(w) == 5 and LETTERS.match(w) and w in freq]
		cands.sort(key=lambda w: freq[w])
		with open(os.path.join(CACHE, "candidatas.txt"), "w", encoding="utf-8") as f:
			f.write("\n".join(f"{w}\t{stems[w]}" for w in cands) + "\n")
		print(f"{len(cands)} candidatas em build/vero/candidatas.txt")


if __name__ == "__main__":
	main()
