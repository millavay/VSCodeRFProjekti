*** Settings ***
Library           OperatingSystem
Library           String
Library           DatabaseLibrary
Library           Collections
Library           SeleniumLibrary
Library           DateTime
Library           validate.py
Library           ibanvalidate.py
Library           validaterowheader.py

*** Variables ***
${Path}       C:\\VSCodeRFProjekti\\

# Database variables
${dbname}    rpakurssi
${dbuser}    robotuser
${dbpass}    password
${dbhost}    localhost
${dbport}    3306

*** Keywords ***

Make Connection
    [Arguments]    ${dbtoconnect}
    Connect To Database    pymysql   ${dbtoconnect}    ${dbuser}    ${dbpass}    ${dbhost}    ${dbport}

*** Keywords ***
Add invoice header to database
#Lisätään laskun header tiedot tietokantaan
    [Arguments]    ${items}
    Make Connection    ${dbname}


    #Muutetaan päivämäärät CSV muodosrta tietokantamuotoon
    ${invoicedate}=    Convert Date    ${items}[3]    date_format=%d.%m.%Y    result_format=%Y.%m.%d
    ${duedate}=    Convert Date    ${items}[4]    date_format=%d.%m.%Y    result_format=%Y.%m.%d

    #luodaan SQL insert lause, jossa käytetään laskun headerin tietoja
    ${insertStmt}=    Set Variable    insert into invoiceheader (invoiceNumber, companyname, referencenumber, invoicedate, duedate, companycode, bankaccountnumber, amountexclvat, vat, totalamount, invoicestatus_id, comments) values ('${items}[0]', '${items}[1]', '${items}[2]', '${invoicedate}', '${duedate}', '${items}[5]', '${items}[6]', ${items}[7], ${items}[8], ${items}[9], -1, 'Processing');

    
    Log    ${insertStmt}
    Execute Sql String    ${insertStmt}

    Disconnect From Database

*** Keywords ***
Add invoiceRow to DB
    #lisätään laskun rivitiedot tietokantaan
    [Arguments]    ${items}
    Make Connection    ${dbname}

    ${insertStmt}=    Set Variable    insert ignore into invoicerow (invoicenumber, invoicerownumber, description, quantity, unit, unitprice, vatpercent, vat, total) values ('${items}[7]', '${items}[8]', '${items}[0]', '${items}[1]', '${items}[2]', '${items}[3]', '${items}[4]', '${items}[5]', '${items}[6]');

    Log    ${insertStmt}
    Execute Sql String    ${insertStmt}


    Disconnect From Database
    
*** Tasks ***
Read CSV file to list and add data to database
    #Luetaan CSV tiedostot ja lisätään data tietokantaan

    #Make Connection    ${dbname}
    ${outputHeader}=    Get File    ${PATH}InvoiceHeaderData.csv
    ${outputRows}=    Get File    ${PATH}InvoiceRowData.csv
    Log    ${outputHeader}
    Log    ${outputRows}

    # Jaetaan tiedosto riveihin
    @{headers}=    Split String    ${outputHeader}    \n
    @{rows}=    Split String    ${outputRows}    \n

    #Poistetaan header listasta viimeinen tyhjä rivi ja ensimmäinen header rivi
    ${length}=    Get Length    ${headers}
    ${length}=    Evaluate    ${length} - 1
    ${index}=    Convert To Integer    0

    Remove From List    ${headers}    ${length}
    Remove From List    ${headers}    ${index}

    # next for rows

    ${length}=    Get Length    ${rows}
    ${length}=    Evaluate    ${length} - 1

    Remove From List    ${rows}    ${length}
    Remove From List    ${rows}    ${index}

    Log    ${outputHeader}
    Log    ${outputRows}

    # Loopataan kaikki header rivit, jaetaan csv sarakkeet ; merkin kohdalta
    FOR    ${headerElement}    IN    @{headers}
        Log    ${headerElement}
        @{headerItems}=    Split String    ${headerElement}    ;
    #lisätään header data tietokantaan
        Add invoice header to database    ${headerItems}
        
    END

    # Lisätään rivitietoja tietokantaan, splitataan csv sarakkeet 
    FOR    ${rowElement}    IN    @{rows}
        Log    ${rowElement}
        @{rowItems}=    Split String    ${rowElement}    ;

        Add invoiceRow to DB    ${rowItems}
        
    END

*** Tasks ***
Validate and update validation info to db
    #Validoi laskut ja päivitetään validoinnin tulos tietokantaan 
    #find all invoices with status -1 processing
    #validations: referencenumber, IBAN, invoice row amount vs header amount
    Make Connection    ${dbname}

    #haetaan laskut joiden status on -1
    ${invoices}=    Query    select invoicenumber, referencenumber, bankaccountnumber, totalamount from invoiceheader where invoicestatus_id=-1;

    #Käydään kaikki laskut läpi, validoidaan ja päivitetään status tietokantaan
    FOR    ${element}    IN    @{invoices}
        Log    ${element}
        Log    Reference number is: ${element}[1]    console=True
        ${invoicestatus}=    Set Variable    0
        ${invoicecomment}=    Set Variable    all ok
        
       #validate reference number, tää tulee python tiedostosta
        ${refValid}=    Run Keyword And Return Status    Is Reference Number Correct    ${element}[1]

        Run Keyword If    not ${refValid}    Set Variable    ${invoicestatus}    1
        Run Keyword If    not ${refValid}    Set Variable    ${invoicecomment}    Invalid reference number

        #jos refernce number ei validi, ei tarvitse tarkistaa IBANia, mutta muuten tarkistetaan IBAN
        ${ibanValid}=    Is Iban Correct    ${element}[2]
        ${invoicestatus}=    Set Variable If    not ${ibanValid}    2    ${invoicestatus}
        ${invoicecomment}=    Set Variable If    not ${ibanValid}    Invalid IBAN    ${invoicecomment}

        #Validate: row amount vs header amount, tää tapahtuu ihan vaan tässä, ei keywordii
        ${rowTotal}=    Query    select sum(total) from invoicerow where invoicenumber = '${element}[0]';
        ${amountsMatch}=    Run Keyword And Return Status    Should Be Equal    ${rowTotal}[0][0]    ${element}[3]
        ${invoicestatus}=    Set Variable If    not ${amountsMatch}    4    ${invoicestatus}
        ${invoicecomment}=    Set Variable If    not ${amountsMatch}    Row amounts do not match header    ${invoicecomment}
        
        #update status to db
        @{params}=    Create List    ${invoicestatus}    ${invoicecomment}    ${element}[0]
        ${updateStmt}=    Set Variable    update invoiceheader set invoicestatus_id=%s, comments = %s where invoicenumber = %s;
        Execute Sql String    ${updateStmt}    parameters=@{params}

        
    END

    Disconnect From Database
