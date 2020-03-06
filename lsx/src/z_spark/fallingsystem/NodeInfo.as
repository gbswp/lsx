
package z_spark.fallingsystem//
{
import z_spark.fallingsystem.Node;
import z_spark.fallingsystem.Relation;

	public class NodeInfo{
		public var elderNode:Node;
		public var relationToElder:int;
		
		public var childrenNodes:Array=[];
		
		public function setInfo(node:Node):void{
			elderNode=node.elderNode;
			relationToElder=node.relationToElderNode;
			
			childrenNodes[Relation.SON]=node.childrenNodes[Relation.SON];
			childrenNodes[Relation.LEFT_NEPHEW]=node.childrenNodes[Relation.LEFT_NEPHEW];
			childrenNodes[Relation.RIGHT_NEPHEW]=node.childrenNodes[Relation.RIGHT_NEPHEW];
		}
		
		public function destroy():void{
			childrenNodes.length=0;
			elderNode=null;
		}
		
	}
}