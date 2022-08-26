package main

import (
  "sdk"
)

type SimpleStruct struct {
  Tainted string
  Untainted string
}

type CompoundStruct struct {
  Tainted string
  Nested SimpleStruct
  Untainted string
  M map[string] string
}

func MethodA(ctx sdk.Context, s CompoundStruct) {
  localA := s.Nested.Tainted
  localB := s.Nested.Untainted
  localC := s.M["C"]
  localD := s.Tainted
  rec := sdk.SetFieldRec {
    C: localA,
    D: localB,
  }

  rec2 := rec

  MethodB(ctx, rec2)

  var rec3 sdk.SetFieldRec
  rec3.D = localC
  MethodB(ctx, rec3)

  rec2.C = localD
  MethodB(ctx, rec2)
}

func MethodB(ctx sdk.Context, rec sdk.SetFieldRec){
  sdk.SetField(ctx, rec)
}

func main() {
  var ctx sdk.Context
  var s CompoundStruct
  MethodA(ctx, s)
}
