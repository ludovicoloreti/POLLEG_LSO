
//Per oggetti che ritornano una lista
type List:void { 
    .result*:string
}

//Per aggiungere un server
// .name e .address sono opzionali perchè nel metodo deleteServer 
type ServerSettings:void {
	.name?: string
	.address?: string
}

// Typo generico che ritorna true e eventuali errori
type Result: bool {
	.error?: string 
}

type CopySettings: void{
	.serverName: string
	.repoName: string
	.path: string
}

interface LocalOp {
  RequestResponse: 	listLocalRepos(void)(List),
  					addServer(ServerSettings)(Result),
  					listServers(void)(List),
  					deleteServer(ServerSettings)(Result), 
  					copy(CopySettings)(void)
}




/* INTERFACCIA PER ESPLORARE LE CARTELLE */
type RepoType: void {
	.name: string
}

type FilesType: void {
	.repoName: string
	.version: int 
	.dir*: string
	.file*: void {
		.path?: string
		.content?: undefined
	}
}

type ExploreType: void {
	.dir*: string
	.file*: void {
		.path?: string
		.content?: undefined
	}
}

type SendRepoType: void {
	.repoName: string
	.initialPath: string
	.finalPath?: string
}
interface ExLocal {
  	RequestResponse: explore( SendRepoType )( ExploreType )
}

interface ExExternal {
  	RequestResponse: send( SendRepoType )( FilesType )
}