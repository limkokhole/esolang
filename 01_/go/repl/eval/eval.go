package eval

import (
	"./interp"
	"bytes"
	"sort"
)

type State struct {
	tokens []string
	defs   map[string]*interp.Def
}

func (s *State) Prompt() string {
	if len(s.tokens) > 0 {
		return "... "
	}
	return ". "
}

func (s *State) Eval(tokens []string) string {
	if len(s.tokens) == 0 && len(tokens) > 1 && tokens[0] == "." {
		return s.evalDirective(tokens)
	}
	s.tokens = append(s.tokens, tokens...)
	result := ""
	for {
		res, tokensUsed, discard, incomplete := s.eval()
		if incomplete {
			return result
		}
		if len(result) > 0 {
			result += "\n"
		}
		result += res
		if discard || tokensUsed >= len(s.tokens) {
			s.tokens = nil
			return result
		}
		s.tokens = s.tokens[tokensUsed:]
	}
}

func (s *State) evalDirective(tokens []string) string {
	switch tokens[1] {
	case "?", "help", "h":
		return "help message"
	case "=", "def", "d":
		return directiveDef(s, tokens[2:])
	case "-", "undef", "u":
		for _, token := range tokens[2:] {
			delete(s.defs, token)
		}
		return ""
	default:
		return "unrecognized directive: " + tokens[1]
	}
}

func directiveDef(s *State, tokens []string) string {
	result := ""
	sep := ""
	if len(tokens) == 0 {
		names := make([]string, 0, len(s.defs))
		for name := range s.defs {
			names = append(names, name)
		}
		sort.Strings(names)
		for _, name := range names {
			result += sep + name
			sep = "\n"
		}
		return result
	}
	for _, name := range tokens {
		if def, ok := s.defs[name]; ok {
			for _, show := range def.Show() {
				result += sep + show
				sep = "\n"
			}
		} else {
			result += sep + name + " not defined."
		}
		sep = "\n"
	}
	return result
}

func (s *State) eval() (string, int, bool, bool) {
	if len(s.tokens) == 0 {
		return "", 0, true, false
	}
	if s.tokens[0] == "." {
		return "", 1, false, false
	}
	if s.tokens[0] == "=" || s.tokens[0] == "_" || s.tokens[0][0] == '0' || s.tokens[0][0] == '1' {
		firstIndex := 0
		for i, token := range s.tokens {
			switch token {
			case "=":
				if i > 0 {
					return "invalid expression", 0, true, false
				}
				firstIndex = 1
			case ".":
				return s.evalExpr(firstIndex, i)
			}
		}
		return "", 0, false, true
	}
	eqIndex := -1
	for i, token := range s.tokens {
		switch token {
		case "=":
			if eqIndex >= 0 {
				return "invalid definition", 0, true, false
			}
			eqIndex = i
		case ".":
			if eqIndex >= 0 {
				return s.evalDef(eqIndex, i)
			}
		}
	}
	return "", 0, false, true
}

func (s *State) evalExpr(firstIndex, lastIndex int) (string, int, bool, bool) {
	expr, err := interp.CompileExpr(s.tokens[firstIndex:lastIndex], s.defs)
	if err != nil {
		return err.Error(), 0, true, false
	}
	result := interp.EvalExpr(s.defs, expr, nil)
	var buffer bytes.Buffer
	for {
		bit, res, err := result.Force(s.defs)
		if err != nil {
			return err.Error(), 0, true, false
		}
		if res == nil {
			if _, err = buffer.WriteRune('_'); err != nil {
				return err.Error(), 0, true, false
			}
			return buffer.String(), lastIndex + 1, false, false
		} else if bit {
			if _, err = buffer.WriteRune('1'); err != nil {
				return err.Error(), 0, true, false
			}
		} else {
			if _, err = buffer.WriteRune('0'); err != nil {
				return err.Error(), 0, true, false
			}
		}
		result = res
	}
}

func (s *State) evalDef(eqIndex, lastIndex int) (string, int, bool, bool) {
	clearCompilations := true
	if s.defs == nil {
		s.defs = make(map[string]*interp.Def)
		clearCompilations = false
	}
	if def, ok := s.defs[s.tokens[0]]; ok {
		if err := def.Add(s.tokens[1:eqIndex], s.tokens[eqIndex+1:lastIndex]); err != nil {
			return err.Error(), 0, true, false
		}
		clearCompilations = false
	} else {
		s.defs[s.tokens[0]] = interp.NewDef(s.tokens[0], s.tokens[1:eqIndex], s.tokens[eqIndex+1:lastIndex])
	}
	if clearCompilations {
		for _, def := range s.defs {
			def.ClearCompilation()
		}
	}
	return "", lastIndex + 1, false, false
}
