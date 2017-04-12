// FILE PRINCIPALE DELL'APPLICAZIONE CLIENT J-SYNC

// FILES INCLUSI
// Interfacce JOLIE
include "console.iol"
include "string_utils.iol"
include "json_utils.iol"
include "interfaces/atServer.iol"
include "interfaces/localOp.iol"
// Utils dell'applicazione
include "data/client_utils.ol"


// 
outputPort LocalOp {
	Interfaces: LocalOp
}

// 
outputPort External {
	Interfaces: AtServer
}

// 
constants {
	SERVERS_REPOS = "servers"
}

// Da avviare
embedded {
  Jolie: "services/atServer.ol" in External, "services/Local.ol" in LocalOp
}


init {
	println@Console( "
 
_|_|_|       _|_|     _|         _|         _|_|_|_|     _|_|_|  
_|    _|   _|    _|   _|         _|         _|         _|        
_|_|_|     _|    _|   _|         _|         _|_|_|     _|  _|_|  
_|         _|    _|   _|         _|         _|         _|    _|  
_|           _|_|     _|_|_|_|   _|_|_|_|   _|_|_|_|     _|_|_|  
                                                                 
                    " )()
}


// Punto di avvio del processo
main
{
	// Inizializzazione albero variabili del client date dal json
	json.filename = "data/app.json";
	loadJson; // Metodo definito in "client_utils.ol"

	// Caricamento configurazioni memorizzate su file .json
	// Costanti (user interface)
	APP_NAME = json.root.domain;
	USER_NAME = json.root.name;
	CONSOLE = APP_NAME + "@" + USER_NAME + "$ ";

	// Avvio UI
	println@Console( "\n ######## " + APP_NAME + " " + USER_NAME + ": APPLICAZIONE AVVIATA" + " ######## " )();
	registerForInput@Console()();
	while( stopApp != true ) {

		// Pulizia variabili
		undef( engine );
		undef( resultArrayControl );
		undef( userCommand);

		// Richiesta comando all'utente
		print@Console( "\n\n" + CONSOLE )();
		in ( userCommand );

		// Formatting input
		toLowerCase@StringUtils( userCommand )( userCommand );
		splitRequest = userCommand;
		splitRequest.regex = " ";
		split@StringUtils( splitRequest )( splitResult );
		userCommand << splitResult.result;

		// Verifico che il programma coonosca il comando inserito dall'utente
		// Non confronto le negazioni e affermazioni memorizzate partendo con i = 2
		for( i = 2, i < #json.root.commands, i++ ) {
			containsRequest.array << json.root.commands[i].appearance;
			containsRequest.toFind = userCommand;
			arrayControl;
			if(resultArrayControl) {

				// Set id dell'azione richiesta dall'utente
				//commandID = i;
				engine << json.root.commands[i];
				i = #json.root.commands
			}
		};

		// Se il comando non è stato riconosciuto
		if( !is_defined( engine )) {
			engine.type = "ERR"
		};

		println@Console("\n")();

		// Avvio servizio in risposta alla richiesta dell'utente
		if( engine.type == "ERR" ) { // Servizio non riconosciuto
			println@Console( "\n> ERR: \"" + userCommand + "\" non è riconosciuto come comando interno.\n" )();
			helpCommand
		} else
		if( engine.type == "CLOSE" ) { // Chiusura applicazione
			print@Console( "> Terminare l'esecuzione? " )();
			in( answer );

			// Controllo risposta utente
			containsRequest.array << json.root.commands[1].appearance;
			containsRequest.toFind = answer;
			arrayControl;
			
			if( resultArrayControl ) {
				stopApp = true
			} else {
				println@Console("> Operazione annullata")()
			}
		} else
		if( engine.type == "HELP" ) { // Comando help

			helpCommand

		} else
		if( engine.type == "LIST" ) { // Richiesta di un servizio lista
			if( is_defined( userCommand[1] ) ) { // Controllo il parametro passato: Se esiste ( e deve esistere ) ...
				for( listIndex = 0, listIndex < #engine.arguments, listIndex++ ) { // Ricerca del parametro all'interno di LIST
					containsRequest.array << engine.arguments[listIndex].commands;
					containsRequest.toFind = userCommand[1];
					arrayControl;
					if(resultArrayControl) { // Il parametro esiste, avvio il servizio dedicato
						if( engine.arguments[listIndex].name == "SERVERS" ) {
							// // AVVIA SERVIZIO "list servers" // //

							// INIZIO - SERVIZO //
							// LIST SERVERS
							// Mostro i Servers Registrati in locale
							// Rimando al servizio che mi mostrerà i servers registrati (leggendo il Json)
							listServers@LocalOp()(serverList);

							// Indento i dati per il cli
							// Print dei risultati ricav
							for(i=0, i<#serverList.result, i++){
								options.command[i] = serverList.result[i];
								println@Console( "> " + serverList.result[i] )()
							}

							// FINE - SERVIZIO //
						} else
						if ( engine.arguments[listIndex].name == "NEW_REPOS" ) {
							// AVVIA SERVIZIO "list new_repos"

							// GET NEW REPOS 
							// cerco in tutti i  servers registrati le repositories disponibili e le mando. Il compito viene svolto da atServer.ol 
							// Qui ci limitiamo a tradurre il risultato listRepos [di tipo ListRepos] in options, così da poterlo mostrare in console
							getRepos@External()(listRepos);
							for(i=0, i<#listRepos.result, i++){
								println@Console( "> " + listRepos.result[i] )()
							}
						} else
						if ( engine.arguments[listIndex].name == "REG_REPOS" ) {
							// AVVIA SERVIZIO "list reg_repos"

							// SHOW CLIENT REPOSITORIES
							//lista delle repos nel client: guardo quali repo ho sul client e su quali server. È molto simile al get new repos come concetto 
							// [qua lo vediamo funzionare alla stessa maniera] ma funziona diversamente in quanto, essendo tutto in locale è il client
							// a cercare quali repos esistono tramite il file Local.ol
							listLocalRepos@LocalOp(void)(list);
							for(i=0, i<#list.result, i++){
								println@Console( "> " + list.result[i] )()
							}
						};
						// Esco dal ciclo
						listIndex = #engine.arguments
					}
				};
				if(!resultArrayControl) {// Il parametro non è corretto
					println@Console("> ERR: \"" + userCommand[1] + "\" non è un parametro valido di LIST\n")();
					helpSpecificCommand
				}
			} else { // Non è stato inserito un parametro
				println@Console("> ERR: Inserire un parametro di LIST\n")();
				helpSpecificCommand
			}
		} else
		if( engine.type == "SERVER" ) { // Richiesta di un servizio lista
			if( is_defined( userCommand[1] ) ) { // Controllo il parametro passato: Se esiste ( e deve esistere ) ...
				for( serverIndex = 0, serverIndex < #engine.arguments, serverIndex++ ) { // Ricerca del parametro all'interno di LIST
					containsRequest.array << engine.arguments[serverIndex].commands;
					containsRequest.toFind = userCommand[1];
					arrayControl;
					if(resultArrayControl) { // Il parametro esiste, avvio il servizio dedicato
						if( engine.arguments[serverIndex].name == "ADD_SERVERS" ) {

							if(is_defined( userCommand[2] )){
								serverSettings.name = userCommand[2];

								if(is_defined( userCommand[3] )){
									serverSettings.address = userCommand[3];
									eseguibile = true
								} else {
									eseguibile = false
								}
							} else {
								eseguibile = false
							};
							// AVVIA SERVIZIO "add_Server"
							// ADD SERVER: Aggiungo un server alla lista di server.json. È una operazione delicata perchè devo aprire un json, modificarlo e 
							// infine ricaricarlo. Tuttavia non è un problema in quanto il client effettivamente è come se eseguisse in sequential dato che
							// eseguiamo un comando alla volta da console.
							// Non dovremmo quindi, in via teorica, aver problemi
							print@Console( "> Inserire il nome del nuovo server: " )();
							in( serverSettings.name );
							trim@StringUtils( serverSettings.name )( serverSettings.name );
							print@Console( "> Inserire l'indirizzo del nuovo server: " )();
							in( serverSettings.address );
							trim@StringUtils( serverSettings.address )( serverSettings.address );
							print@Console( "> Nome Server: " + serverSettings.name + " -  Porta: " + serverSettings.address + "; Continuare? " )();
							in( answer );
							// Controllo risposta utente
							containsRequest.array << json.root.commands[1].appearance;
							containsRequest.toFind = answer;
							arrayControl;
							if ( resultArrayControl ) {
								/* 
									Presumo di avere 2 input:
										- Nome (string)
										- Porta (int)
									Non mi preoccupo di avere i dati giusti, ci penserà il servizio per me
								*/
								// Eseguo il comando addServer dopo aver indentato i dati
								addServer@LocalOp(serverSettings)(risultato);
								//Se la variabile risultato è true, vuol dire che è andato tutto a buon fine,
								//Se la variabile risultato è false, il server non è stato creato
								if(risultato){
									println@Console( "> Server " + input.result[1] + " aggiunto correttamente sulla porta " + input.result[2] )()
								} else {
									println@Console( "> ERR: Impossibile registrare il server: " + risultato.error )()
								}
							} else {
								println@Console("> Operazione annullata")()
							}
							
						} else
						if ( engine.arguments[serverIndex].name == "REM_SERVERS" ) {
							// AVVIA SERVIZIO "remove_serverv"

							// REMOVE SERVER
							// Ricevo in entrata il nome del server o l'indirizzo da eliminare
							// Restituisco true o false in caso sia riuscito o no ad elimanare 
							// il server dalla lista
							undef( serverSettings );
							undef( answer );

							// Richiesta nome server all'utente
							print@Console( "> Inserire il nome del server: " )();
							in( answer );
							trim@StringUtils( answer )( answer );


							if( is_defined( answer ) ) {
								number = int( answer );
								if(number!=0){
									serverSettings.address = answer
								} else {
									serverSettings.name = answer
								};

								print@Console( "> Rimuovere il server? " )();
								in( answer );
								// Controllo risposta utente
								containsRequest.array << json.root.commands[1].appearance;
								containsRequest.toFind = answer;
								arrayControl;
								if( resultArrayControl ) {
									// Richiesta servizio
									deleteServer@LocalOp(serverSettings)(risultato);
									// Elaborazione risultato
									if(risultato){
										println@Console( "> Server rimosso dalla lista" )()
									} else {
										println@Console( "> ERR: " + risultato.error )()
									}
								} else {
									println@Console("> Operazione annullata")()
								}
							}
						};
						// Esco dal ciclo
						serverIndex = #engine.arguments
					}
				};
				if(!resultArrayControl) {// Il parametro non è corretto
					println@Console("> ERR: \"" + userCommand[1] + "\" non è un parametro valido di SERVER\n")();
					helpSpecificCommand
				}
			} else { // Non è stato inserito un parametro
				println@Console("> ERR: Inserire un parametro di SERVER\n")();
				helpSpecificCommand
			}
		} else
		if( engine.type == "REPOSITORY" ) {
			if( is_defined( userCommand[1] ) ) { // Controllo il parametro passato: Se esiste ( e deve esistere ) ...
				for( repositoryIndex = 0, repositoryIndex < #engine.arguments, repositoryIndex++ ) { // Ricerca del parametro all'interno di LIST
					containsRequest.array << engine.arguments[repositoryIndex].commands;
					containsRequest.toFind = userCommand[1];
					arrayControl;
					if(resultArrayControl) { // Il parametro esiste, avvio il servizio dedicato
						if( engine.arguments[repositoryIndex].name == "ADD_REPOSITORY" ) {
							// AVVIA SERVIZIO "addRepository"
							// var utilizzata: repositorySettings
							undef( repositorySettings );

							print@Console( "> Inserire il nome del server legato al repository: " )();
							in( repositorySettings.serverName );
							trim@StringUtils( repositorySettings.serverName )( repositorySettings.serverName );
							print@Console( "> Inserire il nome del nuovo repository: " )();
							in( repositorySettings.name );
							trim@StringUtils( repositorySettings.name )( repositorySettings.name );
							print@Console( "> Inserire il Path in cui è la cartella da aggiungere: " )();
							in(repositorySettings.path);
							trim@StringUtils( repositorySettings.path )(repositorySettings.path);
							print@Console( "> Nome Server: " + repositorySettings.serverName + " -  Repository: " + repositorySettings.name + " -  LocalPath: " + repositorySettings.path + "; Continuare? " )();
							in( answer );
							// Controllo risposta utente
							containsRequest.array << json.root.commands[1].appearance;
							containsRequest.toFind = answer;
							arrayControl;
							if ( resultArrayControl ) {
								// TODO:
								// INSERIRE SERVIZIO addRepository
								// repositorySettings.serverName = NOME_SERVER - repositorySettings.name = NOME_REPO - repositorySettings.path = LOCALPATH
								
								/*
									per prima cosa dobbiamo prendere il file e inviarlo al server dopo aver visto che non abbiamo la repo già registrato.
									Così vediamo se è disposto ad accettare la nostra NUOVA repo
								*/
								exists@File(repositorySettings.path)(esistePercorso); 
								isDirectory@File(repositorySettings.path)(isCartella);

								if(esistePercorso && isCartella){
									exists@File(SERVERS_REPOS+"/"+repositorySettings.serverName+"/"+repositorySettings.name + "/.version")(exist);

									if(!exist){
										//inviamo il file al server e vediamo cosa risponde
										createOrganize@External(repositorySettings)(response)
									} else{
										println@Console( "> Percorso LocalPath non valido: Già esistente" )()
									};

									/* 	
										Se repoName non esiste sul server, lo creiamo.
										Se non esiste in locale, viene creato.
									*/
									//Guardo se localPath funziona

									println@Console( "Response.error " + response.error +"[or Null]")();
									if( !is_defined( response.error ) && !exist){
										//Copio i dati da localPath alla mia cartella dentro il programma
										copy@LocalOp({.path = repositorySettings.path, .repoName = repositorySettings.name, .serverName=repositorySettings.serverName})();
										println@Console( "Finito" )()
									} else {
										println@Console( "> Repository già esistente su " + repositorySettings.serverName )()
									}
								} else {
									println@Console( "> Percorso LocalPath non valido: non esiste o non è una cartella" )()
								}

							} else {
								println@Console("> Operazione annullata")()
							}
						} else
						if ( engine.arguments[repositoryIndex].name == "REM_REPOSITORY" ) {
							// AVVIA SERVIZIO "delete"
							// var utilizzata: repositorySettings
							undef( repositorySettings );
							print@Console( "> Inserire il nome del server legato al repository: " )();
							in( repositorySettings.serverName );
							trim@StringUtils( repositorySettings.serverName )( repositorySettings.serverName );
							print@Console( "> Inserire il nome della repository da cancellare: " )();
							in( repositorySettings.name );
							trim@StringUtils( repositorySettings.name )( repositorySettings.name );
							print@Console( "> Nome Server: " + repositorySettings.serverName + " -  Repository: " + repositorySettings.name + "; Continuare? " )();
							in( answer );
							// Controllo risposta utente
							containsRequest.array << json.root.commands[1].appearance;
							containsRequest.toFind = answer;
							arrayControl;
							if ( resultArrayControl ) {
								// TODO:
								// INSERIRE SERVIZIO delete
								// repositorySettings.serverName = NOME_SERVER - repositorySettings.name = NOME_REPO

								exists@File(SERVERS_REPOS + "/" + repositorySettings.serverName + "/" + repositorySettings.name)(existsRepo);
								println@Console( SERVERS_REPOS + "/" + repositorySettings.serverName + "/" + repositorySettings.name )();

								//Se existsRepo == true allora la repo esiste sul client e possiamo "pensare di cancellarla"
								if(existsRepo){
									deleteOrganize@External(repositorySettings)(deleteRepoResponseServer);

									if( deleteRepoResponseServer ) {
										//Visto che la cancellazione sul server è andata a buon fine, posso cancellare anche in locale
										deleteDir@File(SERVERS_REPOS + "/" + repositorySettings.serverName+ "/" + repositorySettings.name)(deleteRepoResponseLocal);

										if(deleteRepoResponseLocal){
											println@Console( "> La cancellazione di " + repositorySettings.name + " sul Server " + repositorySettings.serverName + " è andata a buon fine" )()
										} else {
											//Non dovrebbe mai verificarsi dato che abbiamo fatto il controllo di esistenza all'inizio
											println@Console( "> La cancellazione di " + repositorySettings.name + " in locale non è andata a buon fine" )()
										}
									} else {
										println@Console( "> La cancellazione di " + repositorySettings.name + " sul Server " + repositorySettings.serverName + " non è andata a buon fine" )()
									}

								} else {
									println@Console( "> Repository non esistente in locale" )()
								}


							} else {
								println@Console("> Operazione annullata")()
							}
						};
						// Esco dal ciclo
						repositoryIndex = #engine.arguments
					}
				};
				if(!resultArrayControl) {// Il parametro non è corretto
					println@Console("> ERR: \"" + userCommand[1] + "\" non è un parametro valido di REPOSITORY\n")();
					helpSpecificCommand
				}
			} else { // Non è stato inserito un parametro
				println@Console("> ERR: Inserire un parametro di REPOSITORY\n")();
				helpSpecificCommand
			}
		} else
		if( engine.type == "PUSH" ) {
			// var utilizzata: pushSettings
			undef( pushSettings );
			print@Console( "> Inserire il nome del server legato al repository: " )();
			in( pushSettings.serverName );
			trim@StringUtils( pushSettings.serverName )( pushSettings.serverName );
			print@Console( "> Inserire il nome della repository: " )();
			in( pushSettings.repoName );
			trim@StringUtils( pushSettings.repoName )( pushSettings.repoName );
			print@Console( "> Nome Server: " + pushSettings.serverName + " -  Repository: " + pushSettings.repoName + "; Continuare? " )();
			in( answer );
			// Controllo risposta utente
			containsRequest.array << json.root.commands[1].appearance;
			containsRequest.toFind = answer;
			arrayControl;
			if ( resultArrayControl ) {
				// TODO:
				// INSERIRE SERVIZIO push
				// pushSettings.serverName = NOME_SERVER - pushSettings.repoName = NOME_REPO

				pushOrganize@External(pushSettings)(resp);
				println@Console( resp.error )()
			} else {
				println@Console("> Operazione annullata")()
			}
		} else
		if( engine.type == "PULL" ) {
			// var utilizzata: pushSettings
			undef( pullSettings );
			print@Console( "> Inserire il nome del server legato al repository: " )();
			in( pullSettings.serverName );
			trim@StringUtils( pullSettings.serverName )( pullSettings.serverName );
			print@Console( "> Inserire il nome della repository: " )();
			in( pullSettings.repoName );
			trim@StringUtils( pullSettings.repoName )( pullSettings.repoName );
			print@Console( "> Nome Server: " + pullSettings.serverName + " -  Repository: " + pullSettings.repoName + "; Continuare? " )();
			in( answer );
			// Controllo risposta utente
			containsRequest.array << json.root.commands[1].appearance;
			containsRequest.toFind = answer;
			arrayControl;
			if ( resultArrayControl ) {
				// TODO:
				// INSERIRE SERVIZIO push
				// pushSettings.serverName = NOME_SERVER - pushSettings.repoName = NOME_REPO
				pullOrganize@External(pullSettings)(resp);

				println@Console( resp.error )()
			} else {
				println@Console("> Operazione annullata")()
			}
		}
	};
	println@Console( "\n\n ######## " + APP_NAME + " " + USER_NAME + ": APPLICAZIONE TERMINATA" + " ######## " )()
}