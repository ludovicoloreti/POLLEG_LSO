include "console.iol"
include "file.iol"
include "runtime.iol"
include "string_utils.iol"
//interfacce del programma
include "interfaces/server_interface.iol"

/* Servzio readFile
*
* Questo servzio ha lo scopo di scorrere l'albero di directory e file a partire 
* dal percorso specificato in input.
* Il servizio che deve essere richiamato dall'esterno è send.
* 
*/
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
	// ricorsione
	getLocalLocation@Runtime()( Self.location )
}

main {
	
	[send( path )( toSend ){
		//path.repoName
		//path.initialPath
		//path.finalPath
		println@Console( "\nscanned" )();
		if( !is_defined(path.finalPath) ) {
			path.finalPath = path.repoName
		};

		explore@Self( path )( toSend );

		toSend.repoName = path.repoName;
		toSend.version = 0;
		println@Console( "" )()

	}]

	[explore( path )( toSend ){
		
		println@Console( "Inizio explore: "+path.initialPath+"/"+path.repoName )();
		list@File( {.order.byname= true, .directory= path.initialPath+"/"+path.repoName } )( list );
		
		println@Console( "Sono dentro alla dir: "+path.repoName)();

		for (i=0, i<#list.result, i++) {
			println@Console( "\t"+list.result[i] )()
		};
		file=null;
		
		final = path.finalPath;
		toSend.dir[#toSend.dir] = final;
		
		for(i=0, i<#list.result, i++){
		
			print@Console( "E' una dir '"+(path.initialPath+"/"+path.repoName+"/"+list.result[i])+"' ? " )();
			isDirectory@File( path.initialPath+"/"+path.repoName+"/"+list.result[i] )( result ); //controllo se è una directory
			
			if(result){ 
				
				println@Console( "SI" )();
				toSend.dir[#toSend.dir-1] = final+"/"+list.result[i];
				println@Console( toSend.dir[#toSend.dir-1] )();

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

				println@Console( "NO" )();
				pos = #toSend.file;
				toSend.file[pos].path = path.finalPath+"/"+list.result[i];
				println@Console( "Path: "+toSend.file[pos].path )();
				readFile@File( {.filename = path.initialPath+"/"+path.repoName+"/"+list.result[i], .format= "binary" } )( cont );
				toSend.file[pos].content = cont

			}
		}
	}]

}
