include "file.iol"
include "runtime.iol"
include "string_utils.iol"
include "../Interfaces/localOp.iol"

execution{ concurrent }

inputPort Self {
	Location: "local"
	Interfaces: ExLocal
}
inputPort External {
	Location: "local"
	Interfaces: ExExternal
}
outputPort Self {
	Interfaces: ExLocal
}

init
{
	getLocalLocation@Runtime()( Self.location )
}

main {
	
	[send( path )( toSend ){
		//path.repoName
		//path.initialPath
		//path.finalPath

		if( !is_defined(path.finalPath) ) {
			path.finalPath = path.repoName
		};

		explore@Self( path )( toSend );

		toSend.repoName = path.repoName;
		toSend.version = 0

	}]

	[explore( path )( toSend ){
		
		list@File( {.order.byname= true, .directory= path.initialPath+"/"+path.repoName } )( list );
		//list << list.result; //lista di file e directory
		//toSend.dir[#toSend.dir] = path.repoName;

		file=null;
		
		//println@Console( "'"+list.result[0]+ "'   "+ (list.result[0] instanceof string) )();
		final = path.finalPath;
		toSend.dir[#toSend.dir] = final;
		
		for(i=0, i<#list.result, i++){
		
			isDirectory@File( path.initialPath+"/"+path.repoName+"/"+list.result[i] )( result ); //controllo se è una directory
			
			if(result){ 
				
				toSend.dir[#toSend.dir-1] = final+"/"+list.result[i];

				explore@Self({ .repoName= list.result[i] , .initialPath=path.initialPath+"/"+path.repoName, .finalPath= path.finalPath+"/"+list.result[i] })( res );
				
				for(j=0, j<#res.dir, j++){
					y= #toSend.dir;
					toSend.dir[y] = res.dir[j]
				};

				for(j=0, j<#res.file, j++) {
					x = #toSend.file;
					toSend.file[x].path = res.file[j].path;
					toSend.file[x].content = res.file[j].content
				}

			}else {

				pos = #toSend.file;
				toSend.file[pos].path = path.finalPath+"/"+list.result[i];
				readFile@File( {.filename = path.initialPath+"/"+path.repoName+"/"+list.result[i], .format= "binary" } )( cont );
				toSend.file[pos].content = cont

			}
		}
	}]

}
