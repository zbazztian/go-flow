package sdk

type Context struct { }

type SetFieldRec struct {
  C string
  D string
}

func SetField(ctx Context, rec SetFieldRec) error {
  return nil
}
