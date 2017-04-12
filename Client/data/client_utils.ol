include "file.iol"

// Carica il file json richiesto in una variabile ad albero
define loadJson
{
	// Utilizzo del metodo:
	// json.filename = PATH_FILE_JSON
	// json.root è la radice del file json memorizzato
	readFile@File(json)(json.file);
	getJsonValue@JsonUtils(json.file)(json.root)
}

// Controlla che all'interno di un certo array ci sia la parola cercata
define arrayControl
{
	// Utilizzo del metodo:
	// containsRequest.array << ARRAY_DA_CONTROLLARE
	// containsRequest.toFind = ELEMENTO_DA_CONFRONTARE
	// resultArrayControl è il risultato della ricerca in bool
	resultArrayControl = false;
	for( j = 0, j < #containsRequest.array, j++ ) {
		if( containsRequest.array[j] == containsRequest.toFind ) {
			resultArrayControl = true;
			// Blocco il ciclo
			j = #containsRequest.array
		}
	};
	undef( containsRequest );
	undef( j )
}

define helpCommand
{
	println@Console( "> Comandi a disposizione dell'utenza:" )();
	for( helpIndex = 2, helpIndex < #json.root.commands, helpIndex++ ) {
		outputHelp = json.root.commands[helpIndex].type;
		if( #json.root.commands[helpIndex].arguments > 0 ) {
			outputHelp += "\n\t";
			for( hI = 0, hI < #json.root.commands[helpIndex].arguments, hI++ ) {
				outputHelp += " " + json.root.commands[helpIndex].arguments[hI].name;
				if( hI + 1 == #json.root.commands[helpIndex].arguments ) {
					outputHelp += ";"
				} else {
					outputHelp += ","
				}
			}
		};
		println@Console( "\n> " + outputHelp )();
		println@Console( "\t" + json.root.commands[helpIndex].description )()
	}
}

// Informazioni legate allo specifico comando
define helpSpecificCommand
{

	// COMANDO TYPE: specificCommand

	println@Console( "> Descrizione breve del comando " + engine.type + ":" )();

	println@Console( "\t" + engine.description )();

	println@Console( "\n\n> Parametri da inserire dopo il comando " + engine.type + ":" )();

	// Per tutti gli arguments del comando:
	for( specificHelpIndex = 0, specificHelpIndex < #engine.arguments, specificHelpIndex++ ) {
		println@Console( "\n\n> " + engine.arguments[specificHelpIndex].name )();
		println@Console( "\t " + engine.arguments[specificHelpIndex].description )()
	}
}