include "console.iol"
include "file.iol"
include "time.iol"
include "semaphore_utils.iol"
include "json_utils.iol"
include "string_utils.iol"
//interfacce del programma 
include "interfaces/json_interface.iol"
include "interfaces/server_interface.iol"

/*
* File server.ol 
* 
* Contiene i servizi e le procedure del Server.
* 
* Define: checkRepoDir, initRepo, verifyConfig, checkVersion, changeVersion
* Servizi: getRepos, createRepo, deleteRepo, push, pull
*/

execution{ concurrent }

//Costanti
constants {
	FILE_CONFIG = "data/init.json",
	REPO_DIR = "repos/",
	SERVER_LOCATION = "socket://localhost:8001",
	NOME_SERVER = "PollegServer"
}

//Porte 
inputPort ServerIn {
	Location: SERVER_LOCATION
	Protocol: sodep
	Interfaces: ServerInterface
}

outputPort GetJson {
	Interfaces: Json
}

outputPort OutRead {
	
	Interfaces: ExExternal
}

//Servizi embeddati
embedded {
  	Jolie: "services/readFile.ol" in OutRead
	Jolie: "services/GetJson.ol" in GetJson
}

define noHacker {
	crack = false;
	control.substring = "../";
	contains@StringUtils( control )(r);
	if( r ){
		crack = true
	};
	undef( control )

}
define checkRepoDir {
	exists@File(REPO_DIR)(exists);
	if(!exists) {
		mkdir@File( REPO_DIR )( )
	}
}

/*
* Release all lock for handling the repos
*/
define initRepo {
	checkRepoDir;
	list@File( { .dirsOnly = true, .order.byname = true, .directory = REPO_DIR } )( repoList );
	
	for(i=0, i<#repoList.result, i++){
		release@SemaphoreUtils( {.name = "lettura_"+repoList.result[i]} )();
		release@SemaphoreUtils( {.name = "push_"+repoList.result[i]} )();
		release@SemaphoreUtils( {.name = "scrittura_"+repoList.result[i]} )();
		global.lock.( repoList.result[i] ) = false
	}
}

/*
* Load the data from the init.json file (if exists).
* Data: Server Name, Server address, Server port
*/
define verifyConfig {
	
	exists@File(FILE_CONFIG)(esiste);
	if( !esiste ) {
		//doesn't exist, ask parameters
		registerForInput@Console()();
		println@Console("Non esiste il file init.json")();
		println@Console("Inserire nome server: ")();
		in(NOME_SERVER);
		println@Console("Inserire indirizzo server: ")();
		in(ADDRESS);
		println@Console("Inserire porta server: ")();
		in(PORTA);

		parametri.nomeServer= NOME_SERVER;
		parametri.indirizzoServer = ADDRESS;
		parametri.portaServer = PORTA;

		getJsonString@JsonUtils( parametri )( jsonString );
		
		toWrite.content = jsonString;
		toWrite.filename= FILE_CONFIG;

		writeFile@File( toWrite )( void )

	}else {
		//exists, get the config parameters
		getJson@GetJson( FILE_CONFIG )( json_tree );
		//println@Console(json_tree.portaServer)();
		NOME_SERVER = json_tree.nomeServer;
		ADDRESS = json_tree.indirizzoServer;
		PORTA = json_tree.portaServer
	}
}

/*
* Check the version of the asked repo
*/
define checkVersion {
	localRepo = REPO_DIR+pushRequest.repoName;
	exists@File( localRepo+"/.version" )( exists );
	println@Console( "> Esiste \""+localRepo+"/.version\"? " + exists )();
	if(exists) {
		//controllo della versione
		getJson@GetJson( localRepo+"/.version" )( json_tree );
		println@Console( "> Server version : "+json_tree.version+"\t\tClient version : "+pushRequest.version)();
		localVersion = json_tree.version;
	
		if(localVersion == pushRequest.version) {
			println@Console( "> Si può fare la push: localVersion == file.version" )();					
			response.response = true
		} else {
			println@Console( "> Non può fare la push: la tua versione non è aggiornata" )();
			response.response = false;
			response.error = "Non può fare la push: la tua versione non è aggiornata" 
		}
	}
	else {
		println@Console( "> Non esiste il file version." )();
		response.response = false;
		response.error = "Non esiste il file version." 
	}
}

/*
* Change the version number for the required repo.
*/
define changeVersion {
	//println@Console( "Sono in changeVersion" )();
	response.version = localVersion+1;
	//cambio la version
	getJsonString@JsonUtils( response )( jsonString );
	toWrite.content = jsonString;
	toWrite.filename = localRepo+"/.version";
	writeFile@File( toWrite )( void )
}

//Server initialization
init {	
	//semaforo per la creazione di una repo
	release@SemaphoreUtils( {.name = "create"} )();
	//initialize repos
	initRepo;
	println@Console( "" )();
	//enable timestamp for the server's output	
	enableTimestamp@Console(true)();
	//verify the existence of init.json
	verifyConfig;
	//start
	println@Console("> Server '"+NOME_SERVER+"' avviato all' indirizzo: '"+SERVER_LOCATION+"'")();
	println@Console("> In attesa...")()
}



/*
Remeber this error: The first statement of the main procedure 
must be an input if the execution mode is not single
*/
main {	
	/* 
	 * Metodo getRepos
	 *
	 * Restituisce la lista di tutte le repository contenute nel server.
	*/
	[getRepos( void )( repoList ){
		println@Console( "> Arrivata richiesta di GETREPOS" )();
		println@Console( "> Lista delle Repo:" )();
		repoDir.directory = REPO_DIR;
		repoDir.order.byname = true;
		repoDir.dirsOnly = true;
		
		list@File( repoDir )( repoList );
		for(i=0, i<#repoList.result, i++){
			//stampo le directory
 			println@Console(">\t- "+ repoList.result[i] )()
 			
		}
	}] { println@Console( "" )();
		println@Console( "> In attesa..." )() }

	/* 
	 * Primo metodo createRepo (NON UTILIZZATO)
	 *
	 * Riceve in input il nome della cartella e restituisce 
	 * true se è stata creata, false altrimenti
	*/
	[createRepo( repo )( result ) {
		println@Console( "> Arrivata una richista di create per "+repo.name )();
		acquire@SemaphoreUtils( {.name = "create"} )();
			//controlla se la repo è già presente sul server
			exists@File( REPO_DIR+repo.name )( esiste );
			//crea la repo
			//ritorna il risultato 
			if(!esiste){
				mkdir@File( REPO_DIR+repo.name )( result );
				
				parametro.version = 1;
				getJsonString@JsonUtils( parametro )( jsonString );
				toWrite.content = jsonString;
				toWrite.filename = REPO_DIR+repo.name+"/.version";
				
				//scrivo il file .version dentro la repo
				writeFile@File( toWrite )( void );
				println@Console( "> Creata repo: '"+ repo.name+"'" )();
				if( !is_defined( global.lock.( repo.name ) ) ){
					//rilascio i permessi per utilizzare la repo
					release@SemaphoreUtils({ .name = "lettura_"+repo.name })();
					release@SemaphoreUtils({ .name = "push_"+repo.name })();
					release@SemaphoreUtils({ .name = "scrittura_"+repo.name })();
					global.lock.( repo.name ) = false
				}
			}else{

				print@Console( nomeClient+": " )();
				println@Console( "> Repo '"+ repo.name+"' già esistente." )();
				result = false
			};
		release@SemaphoreUtils({.name = "create"})()
	}]{ println@Console( "> In attesa..." )() }

	/*Metodo createRepo2
	*
	* Secondo metodo utilizzato: riceve il nome dei una Repo da creare nel Server con
	* già dei file dentro. 
	*/
	[createRepo2( repo )( result ) {
		println@Console( "" )(); 
		println@Console( "> Arrivata richiesta di CREATE per '"+repo.repoName+"'" )();
		acquire@SemaphoreUtils( {.name = "create"} )();
			
			control = repo.repoName;
			noHacker;
			if(!crack) {
				//controlla se la repo è già presente sul server
				exists@File( REPO_DIR+repo.repoName )( esiste );
				//crea la repo
				//ritorna il risultato 
				if(!esiste){
					mkdir@File( REPO_DIR+repo.repoName )( );
					
					if( is_defined(repo.dir) || is_defined(repo.file) ) {
						println@Console( "> Elenco path delle dir" )();
						for(i = 0, i < #repo.dir, i++){
							println@Console( ">\t- "+repo.dir[i] )();
							mkdir@File( REPO_DIR+repo.dir[i] )( r )

						};

						println@Console( "> Elenco path dei file" )();
						for(i=0, i< #repo.file, i++){
							println@Console( ">\t- "+REPO_DIR+repo.file[i].path )();
							writeFile@File({.filename = REPO_DIR+repo.file[i].path, .content= repo.file[i].content })()

						}
					};
					//creo il parametro version
					parametro.version = 1;
					getJsonString@JsonUtils( parametro )( jsonString );
					toWrite.content = jsonString;
					toWrite.filename = REPO_DIR+repo.repoName+"/.version";
					//scrivo il file .version dentro la repo
					writeFile@File( toWrite )( void );

					println@Console( "> Creata repo: '"+ repo.repoName+"'" )();
					
					//rilascio i lock per lavorare sulla repo, se non sono già esistenti
					if( !is_defined( global.lock.( repo.repoName ) ) ){
						//rilascio i permessi per utilizzare la repo
						release@SemaphoreUtils({ .name = "lettura_"+repo.repoName })();
						release@SemaphoreUtils({ .name = "push_"+repo.repoName })();
						release@SemaphoreUtils({ .name = "scrittura_"+repo.repoName })();
						global.lock.( repo.repoName ) = false
					};

					
					result.version = 1
				}else{

					println@Console( "> Repo '"+ repo.repoName+"' già esistente sul Server." )();
					result.error = "Repo "+repo.repoName+" già esistente sul Server "+NOME_SERVER+"."
				}

			}else {
				println@Console( "Errore: il nome della Repository non è valido" )();
				result.error = "Errore: il nome della Repository non è valido"
			};	
		release@SemaphoreUtils({.name = "create"})()
	}]{ println@Console( "> In attesa..." )() }

	/* 
	 * Metodo deleteRepo.
	 *
	 * Riceve in input il nome della cartella e restituisce 
	 * true se è stata eliminata, false altrimenti
	*/
	[deleteRepo( repo )( result ){
		println@Console( "" )();
		println@Console( "> Richiesta di DELETE di: '"+repo.name+"'" )();
		exists@File( REPO_DIR+repo.name )( esiste );
		
		//controllo il nome della repo
		control = repo.name;
		noHacker;
		if( crack ){ esiste = false };
		
		if( esiste ){
			acquire@SemaphoreUtils( {.name = "push_"+repo.name } )( ris ); 
				global.lock.(repo.name) = true;
				acquire@SemaphoreUtils( {.name = "scrittura_"+repo.name } )( ris ); 
			  	
				  	deleteDir@File( REPO_DIR+repo.name )( result );
				  	global.lock.(repo.name) = false;

					if(!result){
						println@Console( "> Errore nella cancellazione di '"+ repo.name+"'")()
					}else{
						println@Console( "> Cancellata repo: '"+ repo.name+ "'")()
					};
				release@SemaphoreUtils( {.name = "scrittura_"+repo.name } )( ris );
			release@SemaphoreUtils( {.name = "push_"+repo.name } )( ris )
		}else {
			println@Console( "> Errore: la cartella '"+ repo.name+"' non esiste sul Server")();
			result= false
		}
	}] { println@Console( "> In attesa..." )() }

	/* 
	 * Metodo pull.
	 *
	 * Riceve in input il nome della cartella e restituisce 
	 * true se è stata eliminata, false altrimenti
	*/
	[pull( pullRequest )( pullResponse ){
		println@Console( "" )();
		println@Console( "> Richiesta di PULL per: '"+pullRequest.name+"'" )();
		//se esiste o è mai esistita la repo
		if( is_defined( global.lock.(pullRequest.name) )) {
			//Mi blocco se c'è qualcuno che sta scrivendo
			while( global.lock.(pullRequest.name) ) {
				println@Console( "> Attendo 3s se finisce di scrivere "+pullRequest.name+", poi riprovo" )();
				sleep@Time(3000)()
			};
			
			//***Inizio Sezione critica 1***
			//prendo il lock per incrementare il numero di reader e prendere il diritto di lettura
			acquire@SemaphoreUtils( {.name = "lettura_"+pullRequest.name} )( ris ); 
				global.reader.(pullRequest.name)++;
				if( global.reader.(pullRequest.name) == 1 ){
					acquire@SemaphoreUtils( {.name = "scrittura_"+pullRequest.name} )( ris );
					exists@File( REPO_DIR+pullRequest.name )( esistenza )
				};	 
			release@SemaphoreUtils( {.name = "lettura_"+pullRequest.name} )( ris );
			//***Fine Sezione critca 1***

			//LETTURA
			if(esistenza){
				send@OutRead( { .repoName= pullRequest.name, .initialPath= REPO_DIR, .finalPath= pullRequest.name } )( files );
				pullResponse.files << files;
				println@Console( "> Pull di '"+pullRequest.name+"' effettuata con successo" )()
			}else {
				println@Console( "Errore. La repo non esiste!" )();
				pullResponse.error = "La repo non esiste"
			};	

			//*** Inizio Sezione critica 2***
			acquire@SemaphoreUtils( {.name = "lettura_"+pullRequest.name} )( ris ); 
				global.reader.(pullRequest.name)--;
				if( global.reader.(pullRequest.name) == 0 ){
					release@SemaphoreUtils( {.name = "scrittura_"+pullRequest.name} )( ris )
				};
			release@SemaphoreUtils( {.name = "lettura_"+pullRequest.name} )( ris )
			//***Fine Sezione critica 2***
		}else {
			println@Console( "Errore. La repo richiesta non esiste!" )();
			pullResponse.error = "Errore: la repo richiesta non esiste."
		}
	}] { println@Console( "> In attesa..." )() } 

	/* Metodo push.
	 *
	 * Riceve in input il nome della cartella, la versione, i file e le sottodirectory.
	 *
	*/
	[push( pushRequest )( pushResponse ){
		println@Console( "" )();
		println@Console( "> Richiesta di PUSH per: "+pushRequest.repoName )();

		exists@File( REPO_DIR+pushRequest.repoName )( esisteRepo );
		//controllo il nome della repo
		control = pushRequest.repoName;
		noHacker;
		if( crack ){ esisteRepo = false };
		
		if( esisteRepo ){
			//devo notificare l'arrivo di un writer agli altri reader
			acquire@SemaphoreUtils( {.name = "push_"+pushRequest.repoName} )( ris );

				// setto il lock a true così i futuri reader che arrivano aspettano 
				// che il writer abbia finito
				global.lock.(pushRequest.repoName) = true;
				
				//**INIZIO SEZIONE CRITICA SCRITTURA**
				acquire@SemaphoreUtils( {.name = "scrittura_"+pushRequest.repoName} )( ris ); 
					exists@File( REPO_DIR+pushRequest.repoName )(esisteRepo);
					if(esisteRepo){ // LOL^2
						//controllo la versione
						checkVersion;
						if(response.response){
							deleteDir@File( REPO_DIR+pushRequest.repoName )( cancellato );

							println@Console( "> Elenco directory" )();
							for(i = 0, i < #pushRequest.dir, i++){
								println@Console( ">\t- "+pushRequest.dir[i] )();
								mkdir@File( REPO_DIR+pushRequest.dir[i] )( r )

							};
							println@Console( "> Elenco path dei file" )();
							for(i=0, i< #pushRequest.file, i++){
								println@Console( ">\t- "+REPO_DIR+pushRequest.file[i].path )();

								scope( writeHandle )
								{
									install( FileNotFound => {println@Console( "Errore di scrittura del file" )(); response.error = "Errore interno al server: Path sbagliato"});
									writeFile@File({.filename = REPO_DIR+pushRequest.file[i].path, .content= pushRequest.file[i].content })()
								}
							};
							changeVersion;
							pushResponse.version = response.version;
							println@Console( "> Push di '"+pushRequest.repoName+"' effettuata con successo" )()
						}else {

							pushResponse.error = response.error
						}
					}else{
						println@Console( "> Impossibile effettuare la push: la repo non esiste sul Server" )();
						pushResponse.error = "Errore: la repo non esiste sul Server"
					};

				release@SemaphoreUtils( {.name = "scrittura_"+pushRequest.repoName} )( ris );
				//**FINE SEZIONE CRITICA SCRITTURA**
				
				global.lock.(pushRequest.repoName) = false;
			
			release@SemaphoreUtils( {.name = "push_"+pushRequest.repoName} )( ris )
		}else {
			println@Console( "Errore: la repo non esiste sul Server" )();
			pushResponse.error = "Errore: la repo non esiste sul Server"
		}
	}] { println@Console( "> In attesa..." )() }

}