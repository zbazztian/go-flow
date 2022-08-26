/**
 * @id go/sdk-set-field
 * @kind path-problem
 */

import go
import semmle.go.dataflow.TaintTracking3
import semmle.go.dataflow.DataFlow3
import DataFlow::PathGraph

// We consider the second parameter of "MethodA" to be tainted
class TaintedParam extends DataFlow::Node {
  TaintedParam() {
    any(Parameter p | p.getIndex() = 1 and p.getFunction().getName() = "MethodA") =
      this.asParameter()
  }
}

// A read of a tainted field
class TaintedFieldRead extends DataFlow::FieldReadNode {
  TaintedFieldRead() {
    this.getField().getQualifiedName() =
      "main." + ["SimpleStruct.Tainted", "CompoundStruct.Tainted"]
  }
}

// An access of a tainted key-value pair
class TaintedMapAccess extends IndexExpr {
  TaintedMapAccess() { this.getIndex().(StringLit).getValue() = "C" }
}

// Configuration which tracks flow from a tainted struct parameter to
// a tainted field read or a tainted map access
class TaintedStructParamFlowConfig extends TaintTracking3::Configuration {
  TaintedStructParamFlowConfig() { this = "TaintedStructParamFlowConfig" }

  override predicate isSource(DataFlow::Node node) { node instanceof TaintedParam }

  override predicate isSink(DataFlow::Node node) {
    node instanceof TaintedFieldRead or node.asExpr() instanceof TaintedMapAccess
  }
}

// Source of taint for either a field read or a map access
class TaintedStructMemberSource extends DataFlow::Node {
  TaintedParam paramSource;

  TaintedStructMemberSource() {
    exists(TaintedStructParamFlowConfig conf, DataFlow::Node sink |
      conf.hasFlow(paramSource, sink) and this.asExpr() = sink.asExpr()
    )
  }

  TaintedParam getParamSource() { result = paramSource }
}

class FieldAssignSink extends DataFlow::Node {
  string fieldName;
  DataFlow::Node base;

  FieldAssignSink() {
    exists(Field f |
      f.getQualifiedName() = "sdk.SetFieldRec." + fieldName and
      f.getAWrite().writesField(base, f, this)
    )
  }

  string getFieldName() { result = fieldName }

  DataFlow::Node getBase() { result = base }
}

class FieldAssignConfig extends TaintTracking2::Configuration {
  FieldAssignConfig() { this = "FieldAssignConfig" }

  override predicate isSource(DataFlow::Node node) { node instanceof TaintedStructMemberSource }

  override predicate isSink(DataFlow::Node node) { node instanceof FieldAssignSink }
}

class SetFieldRecSource extends DataFlow::Node {
  TaintedStructMemberSource memberSource;
  FieldAssignSink fas;

  SetFieldRecSource() {
    exists(FieldAssignConfig config |
      config.hasFlow(memberSource, fas) and
      exists(DataFlow::Node n | n = fas.getBase() |
        this = n
        or
        exists(SsaDefinition ssadef |
          ssadef.getSourceVariable().getARead() = n and
          this = ssadef.getSourceVariable().getARead() and
          n.asInstruction().getASuccessor*() = this.asInstruction()
        )
      )
    )
  }

  FieldAssignSink getAssignSink() { result = fas }

  TaintedStructMemberSource getTaintedStructMemberSource() { result = memberSource }
}

class SetFieldRecConfig extends TaintTracking::Configuration {
  SetFieldRecConfig() { this = "SetFieldRecConfig" }

  override predicate isSource(DataFlow::Node node) { node instanceof SetFieldRecSource }

  override predicate isSink(DataFlow::Node node) {
    exists(DataFlow::CallNode cn |
      cn.getTarget().getQualifiedName() = "sdk.SetField" and cn.getArgument(1) = node
    )
  }
}

from
  DataFlow::PathNode source, SetFieldRecSource sfrs, DataFlow::PathNode sink, SetFieldRecConfig conf
where conf.hasFlowPath(source, sink) and source.getNode() = sfrs
select sink, source, sink,
  "field: " + sfrs.getAssignSink().getFieldName() + " via $@ of $@ from $@", sfrs.getAssignSink(),
  "this assignment", sfrs.getTaintedStructMemberSource(), "this tainted member",
  sfrs.getTaintedStructMemberSource().getParamSource(), "this original parameter"
