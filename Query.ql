/**
 * @id go/field-flows
 * @kind path-problem
 */

import go
import DataFlow::PathGraph

// We consider the second parameter of methods
// "MethodA", "MethodB", "MethodC" to be tainted
class StructSource extends UntrustedFlowSource::Range {
  StructSource() {
    exists(FuncDef f |
      f.getName().regexpMatch("Method[ABC]") and
      f.getParameter(1) = this.asParameter()
    )
  }
}

// Every field read of `main.StructWithTaintedField.TaintedField` is tainted
// if there is flow from the tainted struct to the field read
class FieldReadSink extends DataFlow::FieldReadNode {
  FieldReadSink() {
    this.getField().getQualifiedName() = "main.StructWithTaintedField.TaintedField"
  }
}

// Map access of field `FieldC` is tainted
// if there is flow from the tainted struct to the access
class MapAccessSink extends IndexExpr {
  MapAccessSink() { this.getIndex().(StringLit).getValue() = "FieldC" }
}

// Configuration which tracks flow from a tainted struct parameter to
// either a field read or map access
class StructFlowConfig extends TaintTracking2::Configuration {
  StructFlowConfig() { this = "StructFlowConfig" }

  override predicate isSource(DataFlow2::Node node) { node instanceof StructSource }

  override predicate isSink(DataFlow2::Node node) {
    node instanceof FieldReadSink or node.asExpr() instanceof MapAccessSink
  }
}

// Source of taint for either a field read or a map access
class Source extends DataFlow::Node {
  Source() {
    exists(StructFlowConfig conf, DataFlow2::Node source, DataFlow2::Node sink |
      conf.hasFlow(source, sink) and this.asExpr() = sink.asExpr()
    )
  }
}

// Sink. Either an argument of `sdk.SetField()` or a struct initialization
// for `SetFieldReq.FieldC`
// TODO: possibly consider field writes to `SetFieldReq.FieldC`
class Sink extends DataFlow::Node {
  Sink() {
    exists(DataFlow::CallNode cn |
      cn.getTarget().getQualifiedName() = "sdk.SetField" and cn.getArgument(1) = this
    )
    or
    exists(KeyValueExpr kve |
      kve.getLiteral().getType().getQualifiedName() = "main.SetFieldReq" and
      kve.getKey().(Ident).getName() = "FieldC" and
      kve.getValue() = this.asExpr()
    )
  }
}

// Configuration which tracks taint from the identified sources to the final sinks.
class FlowConfig extends TaintTracking::Configuration {
  FlowConfig() { this = "FlowConfig" }

  override predicate isSource(DataFlow::Node node) { node instanceof Source }

  override predicate isSink(DataFlow::Node node) { node instanceof Sink }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, FlowConfig conf
where conf.hasFlowPath(source, sink)
select sink, source, sink, "result"
