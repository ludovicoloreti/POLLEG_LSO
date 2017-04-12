include "console.iol"
include "../interfaces/atServer.iol"
include "../Interfaces/localOp.iol"
include "../interfaces/json_interface.iol"
include "../Interfaces/connection.iol"
include "json_utils.iol"
include "file.iol"
include "string_utils.iol"
include "time.iol"


/*
 * atServer.ol
 *
 * Questo file implementa tutti i servizi che possono essere richiesti
 * al client e che devono essere eseguiti mediante la connessione con il server.
 *
 * @authors: Polleg
 * @interface: atServer.iol
 */

/*
 * Porta di input in cui ci mettiamo in ascolto
 */
inputPort Dispatcher {
	Location: "local"
	Interfaces: AtServer
}

/*
 * Output port che si occupa della connessione con il server 
 * È l'unica interfaccia che guarda all'esterno del programma
 */ 
outputPort Connection {
	Location: ""
	Protocol: sodep
	Interfaces: ServerInterface
}

/*
 * Output port che si occupa di leggere file e renderli spedibili
 */
outputPort Local {
	Interfaces: ExExternal
}

/*
 * Output port che si occupa di mandare le variabili una volta che 
 * si è dato il percorso per il file Json in cui leggerle
 */
outputPort Utils {
	Interfaces: Json
}

embedded {
  Jolie: "GetJson.ol" in Utils, Jolie: "ReadFile.ol" in Local
}

constants {
	
	// percorso in cui c'è la lista con memorizzato nom server e indirizzo
	REGISTERED_SERVERS_LIST = "data/servers.json",

	//Percorso in cui sono situate le repos
	INITIAL_PATH = "servers/"
}


/*
 * Questo define si occupa di settare il corretto indirizzo alla comunicazione
 * con il server esterno.
 *
 * Input: cercaServer = nomeServer
 *
 * Return: null -> setta la porta Connection.location con l'indirizzo corretto
 */
define cercoServerByName {

	//setto a null la connessione in modo che, se ho problemi con l'indirizzo, non ne uso uno vecchio
	Connection.location ="";
	getJson@Utils(REGISTERED_SERVERS_LIST)(serversList);

	for(i=0, i<#serversList.servers, i++){
		//Cerco l'indirizzo del server selezionato
		if(serversList.servers[i].nome == cercaServer){
			Connection.location = serversList.servers[i].address;
			i=#serversList.servers //per uscire dal ciclo
		}
	};
	println@Console( "> Connection " + Connection.location )()
}


/*
 * Questo define si occupa di separare nel path il nome della cartella al percorso 
 * precedente alla cartella. È necessario per usare il servizio send di ReadFile.ol
 * 
 * Input -> repositorySettings.path => percorso da analizzare
 */
define scanDir {
	/* Con ogni probabilità nel path la cartella da copiare è l'ultima del percorso.
		perciò splitto il path con i "/" e prendo l'ultimo nome come cartella da esplorare 
		e mandare al metodo send che mi ritorna cartelle e files.
	*/
	splitRequest = repositorySettings.path;
	splitRequest.regex = "/";

	split@StringUtils(splitRequest)(splitResponse);
	dir = splitResponse.result[#splitResponse.result-1];
	//Adesso dovrei avere il nome della cartella
	dir = "/"+dir; 
	/*Adesso ho il negativo di quello che devo avere ovvero:
		Es. path: ~/Jolie/progetto1 [supponiamo voglia caricare progetto 1]
			dir: /progetto1 
			Dovrei rimanere con ~/Jolie Che è quello che voglio uso substring
	*/
	//Calcolo la lunghezza di tutta la stringa path e di dir
	/**/	length@StringUtils(repositorySettings.path)(pathLength);
	/**/	length@StringUtils(dir)(dirLength);
	/**/	subStringRequest = repositorySettings.path;
	/**/	subStringRequest.begin = 0;
	/**/	subStringRequest.end = pathLength-dirLength;
	/**/	substring@StringUtils(subStringRequest)(initialPath);

	// Mando la richiesta al servizio e avrò i dati
	send@Local({.initialPath = initialPath, .repoName = dir})(files)
	
	// Oggetto che mi torna da send (files)
	//		type ExploreType: void {
	//			.dir*: string
	//			.file*: void {
	//				.path?: string
	//				.content?: undefined
}


execution{ concurrent }

main{

	/*
	 * GET REPOS
	 *
	 * Questo servizio si connette ai servers registrati e richiede le repos 
	 * che hanno registrato nel server.
	 *
	 *		+ Return
	 *			type ListRepos:void { 
     *				.result*:string
	 *			}
	 */
	[getRepos()(listaServers){

		undef( listaServers );

		//setto a null la connessione in modo che, se ho problemi con l'indirizzo, non ne uso uno vecchio
		Connection.location = "";

		//Andiamo a prendere il Json in cui sono salvati i servers conosciuti
		getJson@Utils(REGISTERED_SERVERS_LIST)( json_tree );

		print@Console( "\n> Attendere..." )();

		//Facciamo un ciclo for in cui andiamo ad esplorare tutti i servers nella lista
		for(i = 0, i<#json_tree.servers, i++){

			print@Console( "..." )();
			//Setto la connessione all'indirizzo del server 
			serverAddress = json_tree.servers[i].address;

			//Formo le righe che andrò a stampare il titolo di ogni repo. Ovvero stampo i dati del server e sotto le sue repos
			listaServers.result[i] = "Nome Server: " + json_tree.servers[i].nome  + "\t\tIndirizzo: " + serverAddress;


			//Setto l'indirizzo del sever selezionato
			Connection.location = serverAddress;
			//Vado a prendere i dati dal server selezionato e gestisco l'eccezione nel caso 
			// il server non sia acceso/raggiungibile/registrato


			scope( connessione )
			{
				
				install(IOException =>  listaServers.result[i] = listaServers.result[i] + "\n\t\t\t\t IOException, Server non Acceso o non esistente"); 
				install( ConnectException => listaServers.result[i] = listaServers.result[i] + "\n\t\t\t\t ConnectionException");
				//Metto null=null perchè se metto un assegnamento lo va a fare sempre anche quando non c'è una eccezione generataConnetto a:\tServer n. " + i + " nome: " +json_tree.servers[i].nome + " Indirizzo: " + serverAddress + " - Effettivo " + Connection.location)();
				getRepos@Connection()(list); 
				//list è la lista che ho ricevuto, vado ad aggiungere questi risultati in listaServers.result
				for(t=0, t<#list.result, t++){
					//stampo le directory
 					listaServers.result[i] = listaServers.result[i] + "\n\t\t" +list.result[t]
				}
			}
		};
		println@Console( "\n> RESULT" )()
	}]


	/*
	 * PUSH ORGANIZE
	 *
	 * Questo servizio si occupa di organizzare la richiesta da inoltrare al server
	 * in particolare si occupa di prendere il file memorizzato in locale, formattarlo
	 * per l'uso del Server e quindi inviarlo. Dopodichè inoltra la risposta ricevuta.
	 *
	 * 		+ Input
	 * 			type FilesType: void {
	 *			.repoName: string
	 * 			.version: int 
	 * 			.dir*: string
	 *			.file*: void {
	 *				.path?: string
	 *				.content?: undefined
	 *			}
	 *		}
	 *
	 * 		+ Return
	 * 			type PushPullResponse: void {
	 *				.version?: int
	 * 				.error?: string
	 *			}
	 */
	[pushOrganize(pushRequest)(resp){
		/*
		 * Ricevo dal server
		 *		type PushResponse: void {
		 *			.version?: int
		 * 			.error?: string
		 *		}
			*/

		/*
		 *	devo ricevere in pushRequest
		 *	type PushRequest: void {
		 * 		.repoName: string
		 * 		.serverName: string
		 *	}
		 */

		//Per prima cosa cerco l'indirizzo del server e lo setto
		cercaServer = pushRequest.serverName;
		cercoServerByName;


		if(Connection.location == ""){
			// Se la connessione non è stata settata vuol dire che il nome del server non era corretto
			resp.error = "> Server " + pushRequest.serverName + " non registrato."
		} else{
			println@Console( "> Connetto al Server " + Connection.location + "..." )();

			// Chiamo il servizio per esplorare la cartella
			send@Local( { .repoName= pushRequest.repoName, .initialPath= INITIAL_PATH + pushRequest.serverName+"/" } )( pushReq );
			
			// Guardo se esiste il file che andrò a mandare al server
			exists@File( INITIAL_PATH + pushRequest.serverName + "/" +pushRequest.repoName+"/.version" )( esisteVersion );
			

			if( esisteVersion ){
				// Vado a leggere il numero di versione per creare il messaggio da inviare al server
				// infatti la versione sarà inviata all'esterno del file in modo che il server possa leggere
				// la versione senza doversi scaricare il file
				getJson@Utils( INITIAL_PATH + pushRequest.serverName + "/"+pushRequest.repoName+"/.version" )( json_tree );
				pushReq.version = json_tree.version;


				scope( connessione )
				{
					//Gestisco l'eccezione nel caso il server sia spento o la connessione non vada a buon fine
					install(IOException =>  resp.error = "EX==> IOException, Server [" + pushRequest.serverName+ "] non Acceso o non esistente"); 
					install( ConnectException => resp.error = "EX==>  ConnectException, Server [" + pushRequest.serverName + "] non Acceso o non esistente");
				
					//Faccio la richiesta della push al server
					push@Connection(pushReq)(resp)
				};

				// Se mi risponde con una versione aggiornata, lo faccio sapere
				if(is_defined( resp.version )){

					println@Console( "> Aggiornamento proveniente dal server: "+resp.version )()

				} else {

					// notifico eventuali errori
					resp.error = "ERRORI Generati: " + resp.error
				};
				if(is_defined(resp.version)){

					//Aggiorno il numero della versione
					json.version = resp.version;
					println@Console( "> Versione del client ora: "+resp.version)();
					getJsonString@JsonUtils( json )( jsonString );
					toWrite.content = jsonString;
					toWrite.filename = INITIAL_PATH + pushRequest.serverName + "/"+pushRequest.repoName+"/.version";
					writeFile@File( toWrite )( void )

				}
			}else{
				resp.error = "> File o file .version non esistente"
			}
		}

	}]


	/*
	 * PULL ORGANIZE
	 *
	 * Servizio che gestisce la pull dal client al server, fa la richiesta
	 * e poi organizza i dati e li scrive in  memoria
	 *
	 * 		+ Input:
	 *			type PushPullRequest: void {
	 *				.repoName: string
	 *				.serverName: string
	 *			}
	 *
	 *		+ Return:
	 *			type PushPullRequest: void {
	 *				.repoName: string
	 *				.serverName: string
	 *			}
	 */
	[pullOrganize(pullRequest)(resp){

		//Come per la push cerco il nome del server
		cercaServer = pullRequest.serverName;
		cercoServerByName;

		scope( connessione )
		{
			
			install(IOException =>  resp.error = "EX==> IOException, Server [" + pullRequest.serverName+ "] non Acceso o non esistente"); 
			install( ConnectException => resp.error = "EX==>  ConnectException, Server [" + pullRequest.serverName + "] non Acceso o non esistente");
			
			//Faccio la richiesta della pull al server
			pull@Connection({.name=pullRequest.repoName})(response)

		};

		// Se non ho ricevuto errori allora cancello la vecchia repository e metto la nuova
		// altrimenti copio il messaggio di errore e lo mando alla Cli
		if(!is_defined( response.error )){
			
			//Cancello la cartella vecchia 
			deleteDir@File( INITIAL_PATH+ pullRequest.serverName+"/"+pullRequest.repoName )( cancellato );
			
			// Perchè cancello la cartella?
			//
			// Perchè se la repo è uguale alla versione precedende ma senza un file, questa non andrà a cancellarmi
			// il file vecchio.

			//Vado a creare le cartelle
			for(i = 0, i < #response.files.dir, i++){
				mkdir@File( INITIAL_PATH+ pullRequest.serverName+"/"+response.files.dir[i] )( r )
			};

			//Vado ad inserire i files
			for(i=0, i< #response.files.file, i++){
				writeFile@File({.filename = INITIAL_PATH+pullRequest.serverName+"/"+response.files.file[i].path, .content= response.files.file[i].content })()
			}
		} else {
			resp.error << response.error
		}
		
	}]


	/*
	 * CREATE ORGANIZE
	 *
	 * Questo servizio organizza i dati per creare una nuova repo sul server.
	 * Ha bisogno di una cartella da copiare per farne la repository, quindi la prima cosa che andremo a fare
	 * sarà di verificare l'esistenza di quella cartella e verificheremo che la repo non esista in locale. 
	 * Nel caso sia affermativa, manderemo la richiesta al server che scriverà la repo in modo che altri client 
	 * possano vederla. Infine andremo a copiare la cartella nella directory in locale (potremmo fare una pull ma abbiamo
	 * deciso di fare così per non sprecare eccessiva banda, si immagini di mandare dei video per esempio).
	 *
	 * 		+ Input:
	 *			type RepositorySettings: void {
	 *				.serverName: string
	 *				.name: string
	 *				.path?: string
	 *			}
	 *
	 * 		+ Return:
	 *			type PushResponse: void {
	 *				.version?: int
	 *				.error?: string
	 *			}
	 */
	[createOrganize(repositorySettings)(response){


		scanDir;

		cercaServer = repositorySettings.serverName;
		cercoServerByName;

		fileRequest.repoName = repositorySettings.name;
		fileRequest.version = 0;
		fileRequest.dir << files.dir;
		fileRequest.file << files.file;


		for (i=0, i<#fileRequest.dir, i++) {

			/* 		Setto la stringa correttmente*/
			/**/	splitRequest = fileRequest.dir[i];
			/**/	splitRequest.regex = "/";
			/**/	split@StringUtils(splitRequest)(splitted);
			/**/	length@StringUtils(splitted.result[1])(reposlength);
			/**/	length@StringUtils(fileRequest.dir[i])(pathLength);
			/**/	subStringRequest=files.dir[i];
			/**/	subStringRequest.begin = reposlength+1;
			/**/	subStringRequest.end = pathLength;
			/**/	substring@StringUtils(subStringRequest)(finalPath);

			fileRequest.dir[i] =  repositorySettings.name + finalPath
		};

		for(i=0, i<#fileRequest.file, i++){

			/* 		Setto la stringa correttmente*/
			/**/	splitRequest = fileRequest.file[i].path;
			/**/	splitRequest.regex = "/";
			/**/	split@StringUtils(splitRequest)(splitted);
			/**/	length@StringUtils(splitted.result[1])(reposlength);
			/**/	length@StringUtils(fileRequest.file[i].path)(pathLength);
			/**/	subStringRequest=fileRequest.file[i].path;
			/**/	subStringRequest.begin = reposlength+1;
			/**/	subStringRequest.end = pathLength;
			/**/	substring@StringUtils(subStringRequest)(finalPath);

			fileRequest.file[i].path = repositorySettings.name + finalPath
		};

		scope( connessione )
		{
			install(IOException => { println@Console( "EX==> IOException, Server [" + pushRequest.serverName+ "] non Acceso o non esistente" )()}); 
			install( ConnectException => {println@Console( "EX==>  ConnectException, Server [" + pushRequest.serverName + "] non Acceso o non esistente" )()});
			
			//Mi connetto al server
			createRepo2@Connection(fileRequest)(response)
		};

		println@Console( "> Repository creata sul server" )()
	}]


	/*
	 * DELETE ORGANIZE
	 *
	 * Questo servizio cancella una repo su un server selezionato
	 */
	[deleteOrganize(repositorySettings)(result){
		
		//Setto la connessione al server
		cercaServer = repositorySettings.serverName;
		cercoServerByName;

		scope( connessione )
		{
			install(IOException => { println@Console( "EX==> IOException, Server [" + pushRequest.serverName+ "] non Acceso o non esistente" )(); result=false}); 
			install( ConnectException => {println@Console( "EX==>  ConnectException, Server [" + pushRequest.serverName + "] non Acceso o non esistente" )(); result=false});
			
			//Eseguo la richiesta
			deleteRepo@Connection({.name=repositorySettings.name})(result)
		}
	}]


}