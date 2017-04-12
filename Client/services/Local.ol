include "console.iol"
include "file.iol"
include "json_utils.iol"
include "string_utils.iol"
include "../interfaces/localOp.iol"
include "../interfaces/json_interface.iol"

/*
 * Local.ol
 *
 * Questo file implementa tutti i servizi che possono essere richiesti
 * al client e che possono essere eseguiti in locale.
 * 
 * Il file esegue pertanto compiti senza richiamare alcun server
 *
 * @authors: Polleg
 * @interface: localOp.iol
 */


/*
 * Porta per input dal client.ol
 */
inputPort Internal {
	Location: "local"
	Interfaces: LocalOp
}

/*
 * Porta per richiedere il servizio di getJson
 */
outputPort Utils {
	Interfaces: Json
}


/* 
 * Porta per richiedere il servizio di esplorazione e get di una cartella
 */
outputPort Explore {
	Interfaces: ExExternal
}

constants {

	// cartella in cui sono le repo
	SERVERS_REPOS = "servers", 
	
	// cartella in cui è salvato il file json con i nomi dei servers associati agli indirizzi
	REGISTERED_SERVERS_LIST = "data/servers.json" 
}

embedded {
  Jolie: "GetJson.ol" in Utils, Jolie: "ReadFile.ol" in Explore
}


/* 
 * RELOAD JSON
 *
 * Scrive il json con i servers registrati una volta modificato
 *
 * reload_tree -> Albero con le variabili
 */
define reloadJson {

	getJsonString@JsonUtils(reload_tree)(serversJsonString);
	

	//Adesso lo andiamo a caricare corretto
	with( writeFileRequest ){
	  .content = serversJsonString;
	  .append = 0;
	  .filename = REGISTERED_SERVERS_LIST
	};

	
	writeFile@File(writeFileRequest)();
	result = true
}


execution{ concurrent }

main {


	/*
	 * LIST LOCAL SERVERS
	 *
	 * Questo servizio permette di leggere i servers disponibili e di creare il comando, pronto per essere scritto in console
	 *
	 * Ritorniamo un semplice type List
	 *
	 * 		+ Return
	 *			type List:void { 
   	 *		 		.result*:string
	 *			}
	 */
	[listServers()(serverList){
		
		// Leggo il Json usando il servizio che ho implementato
		getJson@Utils(REGISTERED_SERVERS_LIST)(servers_tree);

		// copio l'albero servers_tree.servers in servers_tree così da dover scrivere meno righe di codice succesivamente
		servers_tree << servers_tree.servers;

		
		// 	Ora devo verificare che nel json ci sia qualcosa.
		//	Nel caso sia vuoto, lo riporto
		//	Altrimenti vado a comporre il messaggio

		if( !is_defined(servers_tree.address)){
			
			serverList.result = "Non sono presenti server registrati"

		} else {

			//Faccio un ciclo in cui scrivo le opzioni (che andrò a ritornare al Dispatcher.ol)
			for(i=0, i<#servers_tree, i++){
				serverList.result[i] = "Nome Server: " + servers_tree[i].nome + " \tIndirizzo: " + servers_tree[i].address
			}

		}
	}]


	
	/*
	 * LIST LOCAL REPOSITORIES
	 *
	 * Questo servizio permette di scansionare le repo contenute nel  client e di mandarle 
	 * sottoforma di lista al client
	 *
	 *		+ Return:
	 * 			type ListRepos:void { 
 	 *	   			.result*:string
	 *	 		} 
	 */
	[listLocalRepos()(repoString){
		
		//Cerco i nomi dei servers per poi vedere che repos hanno dentro
		request.directory = SERVERS_REPOS;
		request.dirsOnly = true;
		request.order.byname = true;
		list@File(request)(servers);
		//Adesso abbiamo i nomi dei severs, andiamo ad esplorare le directory di ognuno di loro

		for(i=0, i<#servers.result, i++){
			
			//Creo la riga in cui identifico il server in cui sono presenti le repos che andrò a stampare
			repoString.result[i] = "Server: " + servers.result[i];

			//Cerco le repos presente all'interno di quel server

			
			// Perchè divido le repos anche per server??
			//
			// Le divido anche per servers perchè da specifiche ci possono essere repository diverse ma con lo stesso nome.
			// A questo punto l'unica via per identificarle è in base al server di provenienza.
			// Le divido anche perchè così le posso individuare quando le vorrò aggiornare o con pull o con push
			//
			request.directory = SERVERS_REPOS + "/" + servers.result[i];
			list@File(request)(repos);
			repos<<repos.result;

			//stampo i risultati
			for(t=0, t<#repos, t++){
				repoString.result[i] = repoString.result[i] + "\n\t\t\t" + repos[t]
			}

		};

		//Se non ci sono servers registrati lo dico
		if(servers.result==null){
			repoString.result = "Non sono presenti repositories registrati"
		}
	}]




	/*
	 * ADD SERVER
	 *
	 * Questo servizio permette di aggiungere un Server alla lista dei servers registrati
	 * Si prende il file json e lo si legge, modifica e infine lo si riuploada 
	 * nonchè crea la cartella del server in servers
	 *
	 * 		+ Input
	 *			type ServerSettings {
	 *				.name = string
	 *				.address = string
	 *			}
	 *
	 * 		+ Return
	 *			type Result: bool {
	 *				.error?: string 
	 *			}
	 * 
	 */
	[addServer(serverSetting)(result){
		
		//Analizzo i dati, il nome può essere dato a piacere
		result = true;

		// Controllo se i parametri sono settati
		if(serverSetting.name != "" && serverSetting.address!=""){
			
			// Cosa vado a fare:
			// 		+ Prendo il JSON TREE convertito in variabili Jolie
			// 		+ Modifico il Json (se è vuoto allora lo creo)
			// 		+ Riuploado il Json 
			getJson@Utils(REGISTERED_SERVERS_LIST)( json_tree );

			if(!is_defined(json_tree.servers)){

				//Se non ho ancora servers registrati devo creare il json
				json_tree.servers[0].nome = serverSetting.name; 
				json_tree.servers[0].address = "socket://"+serverSetting.address

			} else {

				//Verifico che il server non sia già esistente e la porta non registrata
				for(i=0, i<#json_tree.servers, i++){
					if(json_tree.servers[i].nome == serverSetting.name){
						result = false;
						result.error = result.error + "\tNome già occupato"
					};
					if(json_tree.servers[i].address == "socket://"+serverSetting.address){
						result = false;
						result.error = result.error + "\tIndirizzo già occupato"
					}	
				};

				if(result){
					//Cerco il numero di lunghezza dell'array dei servers. In questa maniera posso aggiungere in coda un elemento
					index = #json_tree.servers;

					// Preparo i dati da inserire
					json_tree.servers[index].nome = serverSetting.name;
					json_tree.servers[index].address =  "socket://"+serverSetting.address
				}
			};

			

			//Aggiorno il Json (ricevo una stringa, non l'ho effettivamente caricato in memoria)
			getJsonString@JsonUtils(json_tree)(serversJsonString);

			//Adesso lo andiamo a caricare aggiornato
			with( writeFileRequest ){
			  .content = serversJsonString;
			  .append = 0;
			  .filename = REGISTERED_SERVERS_LIST
			};

			writeFile@File(writeFileRequest)();

			// Creo la cartella relativa la server aggiunto (in cui metterò le sue repos)
			mkdir@File(SERVERS_REPOS+"/"+serverSetting.name)()
		} else{

			//I parametri esistono già e sono occupati
			result = false;
			result.error = "Nome o Indirizzo non valido"
		}
		
		
	}]


	/*
	 * REMOVE SERVER
	 *
	 * Questo servizio permette di eliminare un Server alla lista dei servers registrati
	 * Si prende il file json e lo si legge, modifica e infine lo si riuploada
	 *
	 * 		+ Input
	 *			type ServerSettings {
	 *				.name? = string
	 *				.address? = string
	 *			}
	 *
	 *		+ Return:
	 *			type Result: bool {
	 *				.error?: string 
	 *			}
	 * 
	 */
	[deleteServer(serverSetting)(result){
		//Prendo il Json e lo carico nella variabile servers_tree
		getJson@Utils(REGISTERED_SERVERS_LIST)(servers_tree);
		//Come al solito copio la variabile servers_tree.servers in servers_tree
		servers_tree << servers_tree.servers;
		serverSetting.address = "socket://localhost:"+serverSetting.address;
		//Identifico in che posizione è il server da elimare
		if(serverSetting.name!=null){
			//Se è presente il nome guardo il nome
			for(i=0, i<#servers_tree, i++){
				if(servers_tree[i].nome == serverSetting.name){
					undef(servers_tree[i]);
					//Pronto per riscrivere il file
					result = true;
					i=#servers_tree //Metodo alternativo per fare il break
				}
			}
		} else if(serverSetting.address != null) {
			//Se è presente l'indirizzo, guardo l'indirizzo
			for(i=0, i<#servers_tree, i++){
				if(servers_tree[i].address == ("socket://" + serverSetting.address)){
					undef(servers_tree[i]);
					//Pronto per riscrivere il file
					result = true;
					i=#servers_tree //Metodo alternativo per fare il break
				}
			}
		} else {
			result = false;
			result.error = "Dati non validi\n"
		};

		if(result){
			//Se ho un risultato positivo
			for(i=0, i<#servers_tree, i++){
				reload_tree.servers[i].nome = servers_tree[i].nome;
				reload_tree.servers[i].address = servers_tree[i].address;
				reload_tree.servers[i].id = servers_tree[i].id
			};
			//Aggiorno il Json
			reloadJson
		} else {
			result = false;
			result.error = result.error + "Server non trovato"
		}

	}]



	/*
	 * COPY
	 *
	 * Questo servizio permette di 
	 *	+ copiare tutti i dati e le cartelle contenute all'interno di una cartella,
	 *  + creare una repo
	 *	+ incollare il contenuto della cartella copiata all'interno della repo creata
	 * 
	 * 		+ Input
	 *			type CopySettings: void{
	 *				.serverName: string
	 * 				.repoName: string
	 *				.path: string
	 *			}
	 */
	[copy(copyRequest)(void){

		// Con ogni probabilità nel path la cartella da copiare è l'ultima del percorso.
	    // perciò splitto il path con i "/" e prendo l'ultimo nome come cartella da esplorare 
		// e mandare al metodo send che mi ritorna cartelle e files.
		
		// Devo splittare il risultato per poter usare send@Explore in path + nomeCartella
		splitRequest = copyRequest.path;
		splitRequest.regex = "/";

		split@StringUtils(splitRequest)(splitResponse);
		dir = splitResponse.result[#splitResponse.result-1];
		//Adesso dovrei avere il nome della cartella
		dir = "/"+dir; 
		println@Console( "PATH " + copyRequest.path )();
		println@Console( "DIR " + dir )();
		/*Adesso ho il negativo di quello che devo avere ovvero:
			Es. path: ~/Jolie/progetto1 [supponiamo voglia caricare progetto 1]
				dir: /progetto1 
				Dovrei rimanere con ~/Jolie Che è quello che voglio uso substring
		*/
		//Calcolo la lunghezza di tutta la stringa path e di dir
		length@StringUtils(copyRequest.path)(pathLength);
		length@StringUtils(dir)(dirLength);
		subStringRequest = copyRequest.path;
		subStringRequest.begin = 0;
		subStringRequest.end = pathLength-dirLength;
		substring@StringUtils(subStringRequest)(initialPath);
		println@Console( initialPath )();

		send@Explore({.initialPath = initialPath, .repoName = dir})(files);
		println@Console( "> Cartella localpath ["+ copyRequest.path+"] scannerizzata" )();
		/*
			type FilesType: void {
			.repoName: string
			.version: int 
			.dir*: string
			.file*: void {
				.path?: string
				.content?: undefined
			}
		}*/

		//Devo salvare i files ricevuti nella nuova repo
		writingPath = SERVERS_REPOS+"/"+ copyRequest.serverName+"/";

		// Analizzo ogni directory che ho ricevuto e la creo all'interno di Repo
		for(i=0, i<#files.dir, i++){

			/* 		devo ricreare il percorso in cui incollare la dir */
			/**/	splitRequest = files.dir[i];
			/**/	splitRequest.regex = "/";
			/**/	split@StringUtils(splitRequest)(splitted);
			/**/	length@StringUtils(splitted.result[1])(reposlength);
			/**/	length@StringUtils(files.dir[i])(pathLength);
			/**/	subStringRequest=files.dir[i];
			/**/	subStringRequest.begin = reposlength+1;
			/**/	subStringRequest.end = pathLength;
			/**/	substring@StringUtils(subStringRequest)(finalPath);
			/**/	println@Console( "FINALPATH " + finalPath )();
			/*		Questo passaggio è necessario in quanto l'interfaccia chiede il nome della repo 
					e il localpath, questi potrebbero differire */


			// Creo la directory
			mkdir@File(writingPath+copyRequest.repoName+"/"+finalPath)()
		};


		//Analizzo ogni file e lo inserisco dentro alle cartelle create
		writingPath = writingPath+copyRequest.repoName+"/";
		for(i=0, i<#files.file, i++){
			
			/* Tolgo la main cartella nel percorso ricevuto (cambiamo il nome della main cartella, in quello specificato nella repo)*/
			/**/	splitRequest = files.file[i].path;
			/**/	splitRequest.regex = "/";
			/**/	split@StringUtils(splitRequest)(splitted);
			/**/	length@StringUtils(splitted.result[1])(reposlength);
			/**/	length@StringUtils(files.file[i].path)(pathLength);
			/**/	subStringRequest=files.file[i].path;
			/**/	subStringRequest.begin = reposlength+1;
			/**/	subStringRequest.end = pathLength;
			/**/	substring@StringUtils(subStringRequest)(finalPath);
			/*		Questo passaggio è necessario in quanto l'interfaccia chiede il nome della repo 
					e il localpath, questi potrebbero differire */

			//Scrivo il file
			writeFile@File( {.content = files.file[i].content, .filename = writingPath + finalPath})()
		};

		//Aggiungo il file .VERSION
		parametro.version = 1;
		getJsonString@JsonUtils( parametro )( jsonString );
		toWrite.content = jsonString;
		toWrite.filename = writingPath +".version";

		//scrivo il file .version dentro la repo
		writeFile@File( toWrite )( void );

		println@Console( "> Versione: 1" )()

	}]
}