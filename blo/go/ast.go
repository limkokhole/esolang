package main

type Ast struct {
	Types map[string]*Type
	Funcs map[string]*Func
}

func newAst() *Ast {
	ast := &Ast{}
	ast.Types = make(map[string]*Type)
	ast.Funcs = make(map[string]*Func)
	return ast
}

type Type struct {
	Name     string
	Imported bool
	Fields   []*Var
}

type Func struct {
	Name     string
	Imported bool
	Params   []*Var
	TypeName string
	Type     *Type
	Body     *StmtBlock
}

type Var struct {
	Name     string
	TypeName string
	Type     *Type
}

type Stmt interface {
	CanFallThru() bool
}

type StmtBlock struct {
	Stmts []Stmt
}

func (s *StmtBlock) CanFallThru() bool {
	for _, stmt := range s.Stmts {
		if !stmt.CanFallThru() {
			return false
		}
	}
	return true
}

type StmtVar struct {
	Name     string
	TypeName string
	Type     *Type
	Expr     Expr
}

func (s *StmtVar) CanFallThru() bool {
	return true
}

type StmtIf struct {
	Expr   Expr
	Stmts  *StmtBlock
	ElseIf *StmtIf
	Else   *StmtBlock
}

func (s *StmtIf) CanFallThru() bool {
	if s.Stmts.CanFallThru() {
		return true
	} else if s.ElseIf != nil {
		if s.Else != nil {
			panic("StmtIf should not have both else if and else")
		}
		return s.ElseIf.CanFallThru()
	} else if s.Else != nil {
		return s.Else.CanFallThru()
	} else {
		return true
	}
}

type StmtFor struct {
	Label Token
	Stmts *StmtBlock
}

func (s *StmtFor) CanFallThru() bool {
	panic("Not yet implemented")
}

type StmtBreak struct {
	Label Token
}

func (s *StmtBreak) CanFallThru() bool {
	return false
}

type StmtReturn struct {
	Expr Expr
}

func (s *StmtReturn) CanFallThru() bool {
	return false
}

type StmtSetClear struct {
	Value bool
	Expr  Expr
}

func (s *StmtSetClear) CanFallThru() bool {
	return true
}

type StmtAssign struct {
	LValue, Expr Expr
}

func (s *StmtAssign) CanFallThru() bool {
	return true
}

type StmtExpr struct {
	Expr Expr
}

func (s *StmtExpr) CanFallThru() bool {
	return true
}

type Expr interface {
	Type() *Type
}

type ExprVar struct {
	Name string
	Var  *Var
}

func (e *ExprVar) Type() *Type {
	if e.Var == nil {
		return nil
	}
	return e.Var.Type
}

type ExprField struct {
	Name string
	Expr Expr
}

func (e *ExprField) Type() *Type {
	t := e.Expr.Type()
	if t == nil {
		return nil
	}
	for _, field := range t.Fields {
		if field.Name == e.Name {
			return field.Type
		}
	}
	return nil
}

type ExprFunc struct {
	Name   string
	Params []Expr
	Func   *Func
}

func (e *ExprFunc) Type() *Type {
	if e.Func == nil {
		return nil
	}
	return e.Func.Type
}
