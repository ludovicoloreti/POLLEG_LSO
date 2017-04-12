//Per repo list
type ListResponse:void { 
    .result*:string
}
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

type TransferType: void {
	.repoName: string
	.content?:  raw
	.error?: string
}

type PullRequest: void {
	.repoName: string
	.clientName?: string
}

type PushResponse: void {
	.version?: int
	.error?: string
}
type PullResponse: void {
	.error?: string
	.files?: FilesType
}

interface ServerInterface {
	RequestResponse : 
		createRepo( RepoType )( bool ),
		createRepo2( FilesType )( PushResponse ),
		getRepos( void )( ListResponse ),
		getIntoRepos( void )( ListResponse ),
		deleteRepo( RepoType )( bool ),
		pull( RepoType )( PullResponse ),
		push( FilesType )( PushResponse )
}



