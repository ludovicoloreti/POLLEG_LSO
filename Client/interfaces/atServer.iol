//Per repo list
type ListRepos:void { 
    .result*:string
}

type PushPullRequest: void {
	.repoName: string
	.serverName: string
}

type PushPullResponse: void {
	.version?: int
	.error?: string
}

type RepositorySettings: void {
	.serverName: string
	.name: string
	.path?: string
}

type PushResponse: void {
	.version?: int
	.error?: string
}

interface AtServer {
  RequestResponse: getRepos(void)(ListRepos),
  					deleteOrganize(RepositorySettings)(bool),
  					createOrganize(RepositorySettings)(PushResponse),
  					pushOrganize(PushPullRequest)(PushPullResponse),
  					pullOrganize(PushPullRequest)(PushPullResponse)
}