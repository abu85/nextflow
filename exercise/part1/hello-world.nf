/*
* print a line called 'Hello,
* World!'
*/
params.outdir = 'results'

process SAY_HELLO { 
    debug true      
    
    publishDir params.outdir, mode: 'copy'

// add input directives
    input: 
    val greeting

// add input directives
    output: 
    path "${greeting}.txt"

 // added a output directive to save the output to a file
    script:
    """
    echo '$greeting' > ${greeting}.txt
    """
}

process CONVERT_TO_UPPER {
    debug true      

    publishDir params.outdir, mode: 'copy'

    // add input directives
    input: 
    path input_file

    // add output directives
    output: 
    path "upper_${input_file}"

    // tr '[:lower:]' '[:upper:]' < $input_file > output_upper.txt # alternative
    
    script:
    """
    cat $input_file | tr '[:lower:]' '[:upper:]' > upper_${input_file}
    """
}

//call the sayhello commands
workflow {

    params.greeting = "Hello"

     // crate a chanell to pass the greeting message
    greeting_ch = channel.of(params.greeting)

    // call the SAYHELLO process with the greeting channel
    SAY_HELLO(greeting_ch)

    // call the CONVERTTOUPPER process with the output of SAYHELLO
    CONVERT_TO_UPPER(SAY_HELLO.out)
}