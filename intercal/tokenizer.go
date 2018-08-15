package main

import (
	"bufio"
	"io"
	"os"
	"sort"
	"strings"
)

type Tokenizer struct {
	r *bufio.Reader

	filename string

	line    string
	linenum int
	index   int

	pushback *Token
}

func NewTokenizer(filename string, r io.Reader) *Tokenizer {
	return &Tokenizer{
		r:        bufio.NewReader(r),
		filename: filename,
	}
}

func NewFileTokenizer(filename string) (*Tokenizer, error) {
	f, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	return NewTokenizer(filename, f), nil
}

func (t *Tokenizer) Next() (*Token, error) {
	if t.pushback != nil {
		tok := t.pushback
		t.pushback = nil
		return tok, nil
	}
	for {
		if t.index >= len(t.line) {
			line, err := t.r.ReadString('\n')
			t.line = line
			if err != nil {
				if line == "" || err != io.EOF {
					return nil, err
				}
			}
			t.linenum++
			t.index = 0
			continue
		}
		if t.line[t.index] == ' ' || t.line[t.index] == '\n' {
			t.index++
			continue
		}
		firstNumber := strings.IndexAny(t.line[t.index:], "0123456789")
		tokenIndex := firstNumber
		tableIndex := -1
		for i, entry := range tokenTable {
			index := strings.Index(t.line[t.index:], entry.Value)
			if index >= 0 && (index < tokenIndex || tokenIndex < 0) {
				tokenIndex = index
				tableIndex = i
			}
		}
		if tokenIndex > 0 {
			colnum := t.index + 1
			stringValue := t.line[t.index : t.index+tokenIndex]
			t.index += tokenIndex
			return &Token{
				Filename:    t.filename,
				LineNum:     t.linenum,
				ColNum:      colnum,
				Type:        TokenString,
				StringValue: stringValue,
			}, nil
		}
		if tableIndex >= 0 {
			colnum := t.index + 1
			t.index += len(tokenTable[tableIndex].Value)
			return &Token{
				Filename:    t.filename,
				LineNum:     t.linenum,
				ColNum:      colnum,
				Type:        tokenTable[tableIndex].Type,
				StringValue: tokenTable[tableIndex].Value,
			}, nil
		} else if firstNumber > 0 {
			colnum := t.index + 1
			stringValue := t.line[t.index : t.index+firstNumber]
			t.index += firstNumber
			return &Token{
				Filename:    t.filename,
				LineNum:     t.linenum,
				ColNum:      colnum,
				Type:        TokenString,
				StringValue: stringValue,
			}, nil
		} else if firstNumber == 0 {
			linenum := t.linenum
			colnum := t.index + 1
			index := t.index
			value := 0
		loop:
			for {
				if index >= len(t.line) {
					line, err := t.r.ReadString('\n')
					t.line = line
					t.linenum++
					index = 0
					if err == io.EOF {
						break loop
					} else if err != nil {
						return nil, err
					}
				}
				switch t.line[index] {
				case ' ', '\n':
				case '0':
					value = value * 10
				case '1':
					value = value*10 + 1
				case '2':
					value = value*10 + 2
				case '3':
					value = value*10 + 3
				case '4':
					value = value*10 + 4
				case '5':
					value = value*10 + 5
				case '6':
					value = value*10 + 6
				case '7':
					value = value*10 + 7
				case '8':
					value = value*10 + 8
				case '9':
					value = value*10 + 9
				default:
					break loop
				}
				index++
				if value >= 65536 {
					return nil, Err017
				}
			}
			t.index = index
			stringValue := t.line[:index]
			if linenum == t.linenum {
				stringValue = t.line[colnum-1 : index]
			}
			return &Token{
				Filename:    t.filename,
				LineNum:     linenum,
				ColNum:      colnum,
				Type:        TokenNumber,
				NumberValue: uint16(value),
				StringValue: stringValue,
			}, nil
		} else {
			colnum := t.index + 1
			stringValue := t.line[t.index:]
			t.index = len(t.line)
			return &Token{
				Filename:    t.filename,
				LineNum:     t.linenum,
				ColNum:      colnum,
				Type:        TokenString,
				StringValue: stringValue,
			}, nil
		}
	}
}

func (t *Tokenizer) Pushback(tok *Token) {
	if t.pushback != nil {
		panic("Multiple pushback")
	}
	t.pushback = tok
}

type TokenType int

type Token struct {
	Filename string
	LineNum  int
	ColNum   int

	Type TokenType

	NumberValue uint16
	StringValue string
}

const (
	TokenNumber TokenType = iota
	TokenString
	TokenSpot
	TokenTwoSpot
	TokenTail
	TokenHybrid
	TokenMesh
	TokenHalfMesh
	TokenSpark
	TokenBackSpark
	TokenWow
	TokenWhat
	TokenRabbitEars
	TokenRabbit
	TokenSpike
	TokenDoubleOhSeven
	TokenWorm
	TokenAngle
	TokenRightAngle
	TokenWax
	TokenWane
	TokenUTurn
	TokenUTurnBack
	TokenEmbrace
	TokenBracelet
	TokenSplat
	TokenAmpersand
	TokenBook
	TokenBookworm
	TokenBigMoney
	TokenChange
	TokenSqiggle
	TokenFlatWorm
	TokenIntersection
	TokenSlat
	TokenBackSlat
	TokenWhirlpool
	TokenHookworm
	TokenShark
	TokenPlease
	TokenDo
	TokenNot
	TokenCalculating
	TokenNext
	TokenNexting
	TokenForget
	TokenForgetting
	TokenResume
	TokenResuming
	TokenStash
	TokenStashing
	TokenRetrieve
	TokenRetrieving
	TokenIgnore
	TokenIgnoring
	TokenRemember
	TokenRemembering
	TokenAbstain
	TokenAbstaining
	TokenFrom
	TokenReinstate
	TokenReinstating
	TokenGive
	TokenGiving
	TokenUp
	TokenWrite
	TokenWriting
	TokenIn
	TokenRead
	TokenReading
	TokenOut
	TokenSub
)

type tokenTableEntry struct {
	Value string
	Type  TokenType
}

var tokenTable = []tokenTableEntry{
	{".", TokenSpot},
	{":", TokenTwoSpot},
	{",", TokenTail},
	{";", TokenHybrid},
	{"#", TokenMesh},
	{"=", TokenHalfMesh},
	{"'", TokenSpark},
	{"`", TokenBackSpark},
	{"!", TokenWow},
	{"\"", TokenRabbitEars},
	{"\".", TokenRabbit},
	{"\"\u0008.", TokenRabbit},
	{"|", TokenSpike},
	{"%", TokenDoubleOhSeven},
	{"-", TokenWorm},
	{"<", TokenAngle},
	{">", TokenRightAngle},
	{"(", TokenWax},
	{")", TokenWane},
	{"[", TokenUTurn},
	{"]", TokenUTurnBack},
	{"{", TokenEmbrace},
	{"}", TokenBracelet},
	{"*", TokenSplat},
	{"&", TokenAmpersand},
	{"V", TokenBook},
	{"\u2228", TokenBook},
	{"V-", TokenBookworm},
	{"V\u0008-", TokenBookworm},
	{"\u22bb", TokenBookworm},
	{"$", TokenBigMoney},
	{"c/", TokenChange},
	{"c\u0008/", TokenChange},
	{"\u00a2", TokenChange},
	{"~", TokenSqiggle},
	{"_", TokenFlatWorm},
	{"+", TokenIntersection},
	{"/", TokenSlat},
	{"\\", TokenBackSlat},
	{"@", TokenWhirlpool},
	{"-'", TokenHookworm},
	{"^", TokenShark},

	{"PLEASE", TokenPlease},
	{"DO", TokenDo},
	{"NOT", TokenNot},
	{"N'T", TokenNot},
	{"CALCULATING", TokenCalculating},
	{"NEXT", TokenNext},
	{"NEXTING", TokenNexting},
	{"FORGET", TokenForget},
	{"FORGETTING", TokenForgetting},
	{"RESUME", TokenResume},
	{"RESUMING", TokenResuming},
	{"STASH", TokenStash},
	{"STASHING", TokenStashing},
	{"RETRIEVE", TokenRetrieve},
	{"RETRIEVING", TokenRetrieving},
	{"IGNORE", TokenIgnore},
	{"IGNORING", TokenIgnoring},
	{"REMEMBER", TokenRemember},
	{"REMEMBERING", TokenRemembering},
	{"ABSTAIN", TokenAbstain},
	{"ABSTAINING", TokenAbstaining},
	{"FROM", TokenFrom},
	{"REINSTATE", TokenReinstate},
	{"REINSTATING", TokenReinstating},
	{"GIVE", TokenGive},
	{"GIVING", TokenGiving},
	{"UP", TokenUp},
	{"WRITE", TokenWrite},
	{"WRITING", TokenWriting},
	{"IN", TokenIn},
	{"READ", TokenRead},
	{"READING", TokenReading},
	{"OUT", TokenOut},
	{"SUB", TokenSub},
}

func init() {
	sort.Slice(tokenTable, func(i, j int) bool {
		return len(tokenTable[i].Value) > len(tokenTable[j].Value)
	})
}
