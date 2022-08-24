package main

import (
  "sdk"
)

type StructWithTaintedField struct {
  TaintedField string
  UntaintedField string
}

type SomeOtherStruct struct {
  Nested StructWithTaintedField
  UntaintedField string
  MapDemo map[string] string
}

func MethodA(ctx sdk.Context, e StructWithTaintedField) error {
  tainted := e.TaintedField;
  if err := sdk.SetField(ctx, tainted); err != nil {
    return err
  }

  var nottainted = e.UntaintedField;
  if err := sdk.SetField(ctx, nottainted); err != nil {
    return err
  }

  return nil;
}

func MethodB(ctx sdk.Context, e SomeOtherStruct) error {
  tainted := e.Nested.TaintedField;
  if err := sdk.SetField(ctx, tainted); err != nil {
    return err
  }

  tainted = e.MapDemo["FieldC"];
  if err := sdk.SetField(ctx, tainted); err != nil {
    return err
  }

  nottainted := e.Nested.UntaintedField;
  if err := sdk.SetField(ctx, nottainted); err != nil {
    return err
  }

  nottainted = e.MapDemo["SomeOtherField"];
  if err := sdk.SetField(ctx, nottainted); err != nil {
    return err
  }

  nottainted = map[string] string { "FieldC": "nottainted" }["FieldC"]
  if err := sdk.SetField(ctx, nottainted); err != nil {
    return err
  }

  return nil
}

type SetFieldReq struct {
    FieldC string
    FieldD string
}

func MethodC(ctx sdk.Context, e StructWithTaintedField) SetFieldReq {
    localVariableA := e.TaintedField
    localVariableB := e.UntaintedField
    req := SetFieldReq {
        FieldC: localVariableA,
        FieldD: localVariableB,
    }
    return req;
}

func main() {
  var ctx sdk.Context
  var s1 StructWithTaintedField
  var s2 SomeOtherStruct
  MethodA(ctx, s1)
  MethodB(ctx, s2)
  MethodC(ctx, s1)
}
