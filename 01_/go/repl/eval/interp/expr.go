package interp

import (
	"errors"
)

type Expr interface {
	Eval(result *Value, defs map[string]*Def) error
}

type literalExpr string

func (expr literalExpr) Eval(result *Value, defs map[string]*Def) error {
	str := string(expr)
	if len(str) == 0 || str == "_" {
		result.val = vnil
		result.next = nil
		result.expr = nil
		result.bindings = nil
		return nil
	} else if str[0] == '0' {
		result.val = v0
	} else if str[0] == '1' {
		result.val = v1
	} else {
		panic("invalid literal:" + str)
	}
	result.next = &Value{
		val:      vthunk,
		next:     nil,
		expr:     literalExpr(str[1:]),
		bindings: result.bindings,
	}
	result.expr = nil
	result.bindings = nil
	return nil
}

type argExpr uint

func (expr argExpr) Eval(result *Value, defs map[string]*Def) error {
	arg := result.bindings[uint(expr)]
	if arg.val == vthunk {
		if err := arg.expr.Eval(arg, defs); err != nil {
			return err
		}
	}
	if arg.val != vthunk {
		result.val = arg.val
		result.next = arg.next
		result.expr = nil
		result.bindings = nil
	}
	return nil
}

type concatExpr [2]Expr

func (expr concatExpr) Eval(result *Value, defs map[string]*Def) error {
	bindings := result.bindings
	if err := expr[0].Eval(result, defs); err != nil {
		return err
	}
	switch result.val {
	case v0, v1:
		result.next = EvalExpr(defs, concatExpr{result.next.expr, expr[1]}, bindings)
	case vnil:
		result.val = vthunk
		result.expr = expr[1]
		result.bindings = bindings
	case vthunk:
		result.expr = concatExpr{result.expr, expr[1]}
	default:
		panic("unreachable")
	}
	return nil
}

type funcallExpr struct {
	def  *Def
	args []Expr
}

func (expr funcallExpr) Eval(result *Value, defs map[string]*Def) error {
	if err := expr.def.compile(defs); err != nil {
		return err
	}
	var args []*Value
	for _, argExpr := range expr.args {
		args = append(args, EvalExpr(defs, argExpr, result.bindings))
	}
DefLoop:
	for _, compiled := range expr.def.compiled {
		if compiled.compileErr != nil {
			return compiled.compileErr
		}
		var bindings []*Value
		for i, param := range compiled.params {
			value := args[i]
			for _, bit := range param.match {
				if b, val, err := value.Force(defs); err != nil {
					return err
				} else if val == nil || b != bit {
					continue DefLoop
				} else {
					value = val
				}
			}
			if param.ptype == paramBind {
				bindings = append(bindings, value)
			} else if param.ptype == paramNil {
				if len(param.match) == 0 {
					if _, val, err := value.Force(defs); err != nil {
						return err
					} else {
						value = val
					}
				}
				if value != nil {
					continue DefLoop
				}
			}
		}
		result.expr = compiled.body
		result.bindings = bindings
		return nil
	}
	return errors.New("no match:" + expr.def.name)
}
