
	
package z_spark.fallingsystem//
{	
	import flash.utils.Dictionary;
	
	import z_spark.core.debug.logger.Logger;
	import z_spark.kxxxlcore.Assert;
	import z_spark.kxxxlcore.GameSize;
	
	internal final class NodeController
	{
		CONFIG::DEBUG{
			private static var s_log:Logger=Logger.getLog("NodeController");
			public static var s_ins:NodeController;
			public function get dbg_roots():Array{return m_roots}
			public function get dbg_nodeMap():Vector.<Node>{return m_nodeMap}
			public function get dbg_noElderNodes():Array{return m_noElderNodes}
			public function get dbg_frozenNodes():Array{return m_frozenNodes}
		};
		
		private var m_roots:Array;
		private var m_noElderNodes:Array;
		private var m_frozenNodesInfo:Dictionary;
		private var m_frozenNodes:Array;
		private var m_nodeMap:Vector.<Node>;
		
		public function isRootNode(index:int):Boolean{return m_roots.indexOf(index)>=0;}
		public function isFrozenNode(index:int):Boolean{return m_frozenNodes.indexOf(index)>=0;}
		public function getNode(index:int):Node{return m_nodeMap[index] as Node;}
		
		public function NodeController()
		{
			m_noElderNodes=[];
			m_frozenNodes=[];
			CONFIG::DEBUG{s_ins=this;}
		}
		
		/**
		 * [20,20,[0,10,20,30,40,50,60],[],[],[],[],[],[]]
		 * @param arr
		 * 
		 */
		public function setData(roadArr:Array,startArr:Array):void{
			m_frozenNodesInfo=new Dictionary();
			m_noElderNodes.length=0;
			m_roots=startArr.concat();
			m_nodeMap=new Vector.<Node>(GameSize.s_cols*GameSize.s_rows);
			for (var j:int=0;j<roadArr.length;j++){
				var subArr:Array=roadArr[j];
				var idx:int=subArr[0];
				var node:Node=new Node(idx,int(idx/GameSize.s_cols));
				m_nodeMap[idx]=node;
				if(startArr.indexOf(idx)<0)m_noElderNodes.push(idx);
				var childNode:Node;
				var i:int=1;
				while(i<subArr.length){
					idx=subArr[i];
					childNode=new Node(idx,int(idx/GameSize.s_cols));
					m_nodeMap[idx]=childNode;
					childNode.setElderNode(node,Relation.SON);
					node=childNode;
					i++;
				}
			}
		}
		
		public function freezeNodes(arr:Array):void
		{
			var indexArr:Array=arr.concat();
			indexArr.sort(Array.NUMERIC);
			CONFIG::DEBUG{
				s_log.info("::freezeNodes()，要冻结的节点：",indexArr);
				var whileTimes:uint=0;
			};
			while(indexArr.length>0){
				var index:int=indexArr.shift();
				
				CONFIG::DEBUG{
					whileTimes++;
					s_log.info("::freezeNodes()，循环次数：",whileTimes,"处理的节点：",index);
				};
				
				if(index>=GameSize.s_cols*GameSize.s_rows || index<0) continue;
				var me:Node=m_nodeMap[index];
				if(m_frozenNodesInfo[me])continue;
				
				var info:NodeInfo=new NodeInfo();
				info.setInfo(me);
				m_frozenNodesInfo[me]=info;
				m_frozenNodes.push(index);
				
				me.setElderNode(null,0);
				var relation:int=Relation.SON;
				while(relation<Relation.MAX_CHILDREN){
					var childNode:Node=me.childrenNodes[relation];
					if(childNode){
						childNode.setElderNode(null,0);
						if(indexArr.indexOf(childNode.index)<0){
							m_noElderNodes.push(childNode.index);
						}
					}
					relation++;
				}
			}
		}
		
		public function meltNodes(arr:Array):void
		{
			var indexArr:Array=arr.concat();
			indexArr.sort(Array.NUMERIC);
			CONFIG::DEBUG{
				s_log.info("::freezeNodes()，要解冻的节点：",indexArr);
				var whileTimes:uint=0;
			};
			while(indexArr.length>0){
				var index:int=indexArr.shift();
				
				CONFIG::DEBUG{
					whileTimes++;
					s_log.info("::freezeNodes()，循环次数：",whileTimes,"处理的节点：",index);
				};
				
				if(index>=GameSize.s_cols*GameSize.s_rows || index<0) continue;
				var me:Node=m_nodeMap[index];
				if(m_frozenNodesInfo[me]==null)continue;
				var info:NodeInfo=m_frozenNodesInfo[me];
				delete m_frozenNodesInfo[me];
				m_frozenNodes.splice(m_frozenNodes.indexOf(index),1);
				
				if(info.elderNode){
					me.setElderNode(info.elderNode,info.relationToElder);
				}
				if(me.elderNode==null)m_noElderNodes.push(index);
				
				var relation:int=Relation.SON;
				while(relation<Relation.MAX_CHILDREN){
					var childNode:Node=info.childrenNodes[relation];
					if(childNode){
						childNode.setElderNode(me,relation);
					}
					relation++;
				}
			}
		}
		
		public function clean():void{
			m_noElderNodes.length=0;
			m_frozenNodes.length=0;
		}
		
		public function tryConnToElder():Array{
			CONFIG::DEBUG{
				s_log.info("::tryConnToElder()，当前无父节点：",m_noElderNodes);
				s_log.info("::tryConnToElder()，当前的冻结节点：",m_frozenNodes);
				var iterTimes:uint=0;
			};
			var filterElderArr:Array=m_frozenNodes.concat();
			var noElderNodes:Array=m_noElderNodes.concat();
			noElderNodes.sort(Array.NUMERIC);
			var result:Array=[];
			while(noElderNodes.length>0){
				var index:int=noElderNodes.shift();
				CONFIG::DEBUG{
					s_log.info("::tryConnToElder()，遍历次数：",++iterTimes);
				};
				
				var flag:Boolean=tryRightUp(index,filterElderArr);
				if(!flag)flag=tryLeftUp(index,filterElderArr);
				
				var me:Node=m_nodeMap[index];
				if(flag ){
					CONFIG::DEBUG{
						s_log.info("::tryConnToElder()，节点",index,"成功找到长辈节点！长辈节点为：",me.elderNode.index);
					};
					if(m_noElderNodes.indexOf(index)>=0)
						m_noElderNodes.splice(m_noElderNodes.indexOf(index));
					
					result.push(index);
					
					//告诉自己的子孙节点；
					fixDescendant(me);
				}else{
					CONFIG::DEBUG{
						s_log.info("::tryConnToElder()，节点",index,"没有成功找到长辈节点！是否被占用：",me.isOccupied);
					};
					if(!me.isOccupied){
						filterElderArr.push(index);
						
						var i:int=Relation.MAX_CHILDREN;
						while(--i>=0){
							var childNode:Node=me.childrenNodes[i];
							if(childNode){
								if(childNode.elderNode==me || childNode.elderNode==null){
									childNode.setElderNode(null,0);
									noElderNodes.push(childNode.index);
								}
							}
						}
						noElderNodes.sort(Array.NUMERIC);
					}
				}
			}
			return result;
		}
		
		private function tryRightUp(index:int,filterElderArr:Array):Boolean{
			Assert.AssertTrue(index>=0 && index<GameSize.s_cols*GameSize.s_rows);
			if(!FUtil.isSameRow(index,index+1))return false;
			var rightUpIndex:int=index+1-GameSize.s_cols;
			if(rightUpIndex<0)return false;
			if(filterElderArr.indexOf(rightUpIndex)>=0)return false;
			
			var me:Node=m_nodeMap[index];
			var rightUpNode:Node=m_nodeMap[rightUpIndex];
			if(rightUpNode==null)return false;
			var rightUpLeftNephewNode:Node=rightUpNode.childrenNodes[Relation.LEFT_NEPHEW];
			if(rightUpLeftNephewNode){
				CONFIG::DEBUG{
					s_log.info("::tryRightUp()，节点"+index+"的视觉右上节点存在左侄子节点，视觉右上节点/左侄子节点为：",rightUpNode.index,rightUpLeftNephewNode.index);
				};
				if(rightUpLeftNephewNode==me){
					me.setElderNode(rightUpNode,Relation.LEFT_NEPHEW);
					return true;
				}else return false;
			}else{
				me.setElderNode(rightUpNode,Relation.LEFT_NEPHEW);
				return true;
			}
		}
		
		private function tryLeftUp(index:int,filterElderArr:Array):Boolean{
			Assert.AssertTrue(index>=0 && index<GameSize.s_cols*GameSize.s_rows);
			if(!FUtil.isSameRow(index,index-1))return false;
			if(index-1<0)return false;
			var leftUpIndex:int=index-1-GameSize.s_cols;
			if(leftUpIndex<0)return false;
			if(filterElderArr.indexOf(leftUpIndex)>=0)return false;
			
			var me:Node=m_nodeMap[index];
			var leftUpNode:Node=m_nodeMap[leftUpIndex];
			if(leftUpNode==null)return false;
			var leftUpRightNephewNode:Node=leftUpNode.childrenNodes[Relation.RIGHT_NEPHEW];
			if(leftUpRightNephewNode){
				CONFIG::DEBUG{
					s_log.info("::tryLeftUp()，节点"+index+"的视觉左上节点存在右侄子节点，视觉左上节点/右侄子节点为：",leftUpNode.index,leftUpRightNephewNode.index);
				};
				if(leftUpRightNephewNode==me){
					me.setElderNode(leftUpNode,Relation.RIGHT_NEPHEW);
					return true;
				}else return false;
			}else{
				me.setElderNode(leftUpNode,Relation.RIGHT_NEPHEW);
				return true;
			}
		}
		
		private function fixChild(fnode:Node,childNode:Node,relation:uint):Boolean{
			if(childNode.elderNode && childNode.elderNode!=fnode){
				if(relation<childNode.relationToElderNode){
					childNode.setElderNode(fnode,relation);
					if(!childNode.isOccupied)fixDescendant(childNode);
				}else{
					fnode.childrenNodes[relation]=null;
				}
			}else{
				childNode.setElderNode(fnode,relation);
				if(!childNode.isOccupied)fixDescendant(childNode);
			}
			return true;
		}
		
		private function fixDescendant(rootNode:Node):void{
			
			var dNode:Node=rootNode.childrenNodes[Relation.SON];
			if(dNode){
				fixChild(rootNode,dNode,Relation.SON);
			}
			
			dNode=rootNode.childrenNodes[Relation.LEFT_NEPHEW];
			if(dNode){
				fixChild(rootNode,dNode,Relation.LEFT_NEPHEW);
			}
			
			dNode=rootNode.childrenNodes[Relation.RIGHT_NEPHEW];
			if(dNode){
				fixChild(rootNode,dNode,Relation.RIGHT_NEPHEW);
			}
			
		}
		
	}
}