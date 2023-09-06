;Gpt4all Pb bindings 
;PB 6.02 windows x64 
;Idle 
;a example basic server example 

Structure llmodel_error 
   *message;            // Human readable error description; Thread-local; guaranteed to survive until next llmodel C API call
   code.l;              // errno; 0 if none
EndStructure ;

Structure arFloat 
  e.f[0] 
EndStructure 
Structure arLong 
  e.l[0] 
EndStructure   

Structure llmodel_prompt_context Align #PB_Structure_AlignC     
    *logits.arfloat;      // logits of current context
    logits_size.i;        // the size of the raw logits vector
    *tokens.arlong;       // current tokens in the context window
    tokens_size.i;        // the size of the raw tokens vector
    n_past.l;             // number of tokens in past conversation
    n_ctx.l;              // number of tokens possible in context window
    n_predict.l;          // number of tokens to predict
    top_k.l;              // top k logits to sample from
    top_p.f;              // nucleus sampling probability threshold
    temp.f;               // temperature to adjust model's output distribution
    n_batch.l;            // number of predictions to generate in parallel
    repeat_penalty.f;     // penalty factor for repeated tokens
    repeat_last_n.f;      // last n tokens to penalize
    context_erase.f;      // percent of context to erase if we exceed the context window
EndStructure 

PrototypeC llmodel_prompt_callback(token_id.l);
PrototypeC llmodel_response_callback(token_id.l,*response); 
PrototypeC llmodel_recalculate_callback(is_recalculating.l);

ImportC  "libllmodel.lib"
  llmodel_model_create(model_path.p-utf8);
  llmodel_model_create2(model_path.p-utf8,build_variant.p-utf8,*error.llmodel_error); 
  llmodel_model_destroy(model.i);
  llmodel_loadModel(model.i,model_path.p-utf8);
  llmodel_isModelLoaded(model.i);
  llmodel_get_state_size(model.i);
  llmodel_save_state_data(model.i,*dest.Ascii);
  llmodel_restore_state_data(model.i,*src.Ascii);
  llmodel_prompt(model,prompt.p-utf8,*prompt_callback,*response_callback,*recalculate_callback,*ctx.llmodel_prompt_context);
  llmodel_setThreadCount(model,n_threads.l);
  llmodel_threadCount.l(model.i);
  llmodel_set_implementation_search_path(path.p-utf8);
  llmodel_get_implementation_search_path();string 
EndImport 


CompilerIf #PB_Compiler_IsMainFile 

EnableExplicit 

CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Windows
    CompilerIf #PB_Compiler_32Bit
      ImportC "" 
        DateUTC.q(t=0) As "_time"  
      EndImport 
    CompilerElse   
      ImportC "" 
        DateUTC.q(t=0) As "time"  
      EndImport 
    CompilerEndIf
  CompilerCase #PB_OS_Linux
    Procedure.q DateUTC()
      ProcedureReturn time_(#Null)
    EndProcedure
  CompilerCase #PB_OS_MacOS
    ImportC ""
      CFAbsoluteTimeGetCurrent.d()
    EndImport
    Procedure.q DateUTC()
      ProcedureReturn CFAbsoluteTimeGetCurrent() + Date(2001, 1, 1, 0, 0, 0)
    EndProcedure
CompilerEndSelect

Procedure.s InternetDate()
  Protected day.s,wday.s,month.s,dateutc,date.s 
   
  DateUtc = DateUTC()
  
  day = RSet(Str(Day(DateUTC)),2,"0") + " "
  
  Select DayOfWeek(dateutc) 
    Case 0 
      wday = "Sun, "  
    Case 1 
      wday = "Mon, "  
    Case 2 
      wday = "Tue, "
    Case 3 
      wday=  "Wed, "  
    Case 4 
      wday = "Thu, "
    Case 5 
      wday = "Fri, " 
    Case 6  
      wday = "Sat, "
  EndSelect 
   
  Select Month(dateutc) 
    Case 1
     month + " Jan "  
    Case 2 
     month + " Feb " 
    Case 3 
     month + " Mar "
    Case 4
     month + " Apr "
    Case 5
     month + " may "
    Case 6   
     month + " Jun "
    Case 7
     month + " Jul "
    Case 8
     month + " Aug "
    Case 9
     month + " Sep "
    Case 10
     month + " Oct " 
    Case 11
     month + " Nov "
    Case 12
     month + " Dec " 
   EndSelect     
  
   date = wday + day + month + FormatDate("%yyyy %hh:%ii:%ss", DateUTC) + " GMT"
  
  ProcedureReturn date 
  
EndProcedure  

Global gCores,gModel,gCtx.llmodel_prompt_context
Global gErr.llmodel_error
Global path.s,gResponce.s,Quit 
Global NewList lchat.s() 

OpenConsole()  

ProcedureC CBResponse(token_id.l,*response);   
    
  Print(PeekS(*response,-1,#PB_UTF8))  
    
  ProcedureReturn #True   
  
EndProcedure 

ProcedureC CBNetResponse(token_id.l,*response);   
  
  gResponce + PeekS(*response,-1,#PB_UTF8)
  
  ProcedureReturn #True   
  
EndProcedure 

ProcedureC CBPrompt(token.l) 
    
    ProcedureReturn #True 
    
EndProcedure   

ProcedureC CBRecalc(is_recalculating.l) 
  
   ProcedureReturn is_recalculating
  
EndProcedure   

Procedure Process(client) 
  Protected length,*buffer,*mem,res,pos,input.s,prompt.s,content.s
  
  *buffer = AllocateMemory($FFFF) 
  length = ReceiveNetworkData(client,*buffer,$ffff)
  
  If PeekS(*buffer,3,#PB_UTF8) = "GET"  
    
    input.s = PeekS(*buffer+5,-1,#PB_UTF8) 
    input = URLDecoder(input)
    pos = FindString(input,"HTTP/1.1")-1 
    input = Left(input,pos)  
    pos = FindString(input,"query?fquery=")
    If pos 
      input = Right(input,Len(input)-(pos+12)) 
      
      FirstElement(lchat())
      InsertElement(lchat()) 
              
      PrintN("input")
      PrintN(input)  
      PrintN("end input") 
      
      prompt.s = "### Human: " + input + " ### Assistant : " +  #CRLF$ 
      llmodel_prompt(gmodel,prompt,@CBPrompt(),@CBNetResponse(),@CBRecalc(),@gctx); 
      
      lchat() = "<p>" + input + "</p>" + "<p>" + gResponce + "</p>" +  #CRLF$   
      
    EndIf 
         
    
    content.s = "<!DOCTYPE html>" + #CRLF$
    content + "<html><head>" + #CRLF$
    content + "<meta charset='utf-8' />" + #CRLF$
    content + "<title>Gpt4all PB</title>" + #CRLF$
    content + "<style> body { background-color: #6600ff; margin: 10%;} h1 { font-family: verdana; color: white;  text-align: center; } p { width: 80%; font-family: verdana; font-size: 18px;  text-align: left; color: white;} " 
    content + "label { font-family: verdana; font-size: 18px;  text-align: left; color: white;}" 
    content +  "input[type=text], select { width: 100%; padding: 12px 20px; margin: 8px 0; display: inline-block; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }"   
    content +  "input[type=submit] { width: 100%; background-color: #0099cc; color: white; padding: 14px 20px; margin: 8px 0; border: none; border-radius: 4px; cursor: pointer; } </style>"  + #CRLF$
    content + "</head><body> <h1>GPT4ALL PB Chat Server</h1>"+ #CRLF$
    content + "<form action='/query'>" + #CRLF$
    content + "<label for='fquery'> Ask me anything anything at all and place it on the wall </label><br>" + #CRLF$
    content + "<input type='text' id='fquery' name='fquery' value=''><br>" + #CRLF$
    content + "<input type='submit' value='submit'>" + #CRLF$
    
    ForEach lchat() 
       content + "<p>" + lchat() + "</p>" + #CRLF$
    Next    
    content + "</body></html>" 
    
    *mem = UTF8(content) 
        
    Length = PokeS(*Buffer, "HTTP/1.1 200 OK" + #CRLF$, -1, #PB_UTF8)                     
    Length + PokeS(*Buffer+Length, InternetDate() + #CRLF$, -1, #PB_UTF8) 
    Length + PokeS(*Buffer+Length, "Server: GPT4ALL PB Chat Server" + #CRLF$, -1, #PB_UTF8)     
    Length + PokeS(*Buffer+Length, "Content-Length: "+Str(MemorySize(*mem)) + #CRLF$, -1, #PB_UTF8)  
    Length + PokeS(*Buffer+Length, "Content-Type:  text/html" + #CRLF$, -1, #PB_UTF8)           
    Length + PokeS(*Buffer+Length, #CRLF$, -1, #PB_UTF8)                                      
    CopyMemory(*mem,*buffer+Length,MemorySize(*mem)) 
    Length + MemorySize(*mem) 
    FreeMemory(*mem)  
    
    SendNetworkData(client,*buffer,length) 
       
    PrintN("output")
    PrintN(gResponce) 
       
    CloseNetworkConnection(client) 
    
     gResponce  = "" 
    
  EndIf  
  
  FreeMemory(*buffer)     
  
EndProcedure     

; = { "### Instruction", "### Prompt", "### Response", "### Human", "### Assistant", "### Context" };
;### Instruction:
;%1
;### Input:
;You are an Elf.
;### Response:

gCores = CountCPUs(#PB_System_ProcessCPUs )

gctx\n_ctx = 1024     ;maxiumum number of tokens in context windows 
gctx\n_predict = 256  ;number of tokens to predict 
gctx\top_k = 50       ;top k logits  
gctx\top_p = 0.970    ;nuclus sampling probabnility threshold  
gctx\temp = 0.25      ;temperature to adjust model's output distribution
gctx\n_batch = gCores     ;number of predictions to generate in parallel   
gctx\repeat_penalty = 1.2  ;penalty factor for repeated tokens
gctx\repeat_last_n = 10    ;last n tokens To penalize 
gctx\context_erase = 0.5   ; percent of context to erase if we exceed the context window

Global Event,ServerEvent,ClientID,gbusy,prompt.s,instruction.s  

path.s = GetPathPart(ProgramFilename()) + "ggml-model-gpt4all-falcon-q4_0.bin"  ;"GPT4All-13B-snoozy.ggmlv3.q4_0.bin" ;"ggml-gpt4all-j-v1.3-groovy.bin" 

gmodel =  llmodel_model_create2(path,"auto",@gerr);
If gmodel  
  If llmodel_setThreadCount(gmodel,gCores)    
    If llmodel_loadModel(gmodel,path)
                
      
      If CreateNetworkServer(0,80, #PB_Network_IPv4 | #PB_Network_TCP);
        OpenWindow(0, 100, 200, 320, 50, "gtp4all")
        Repeat 
          Repeat
            Event = WaitWindowEvent(20)
            Select Event 
              Case #PB_Event_CloseWindow 
                Quit = 1 
              Case #PB_Event_Gadget
                If EventGadget() = 0
                  Quit = 1
                EndIf
            EndSelect
          Until Event = 0
          
          ServerEvent = NetworkServerEvent()
          If ServerEvent
            ClientID = EventClient()
            Select ServerEvent
              Case #PB_NetworkEvent_Connect 
                If gbusy = 0 
                  gbusy = 1
                EndIf   
              Case #PB_NetworkEvent_Data 
                If gbusy
                  Process(clientid) 
                  gbusy=0 
                EndIf   
            EndSelect  
          EndIf   
        Until Quit = 1
        CloseNetworkServer(0)
      EndIf         
      llmodel_model_destroy(gModel) 
    Else 
      MessageRequester("Error","Failed to load Model") 
      End 
    EndIf   
  EndIf 
  
EndIf 

CompilerEndIf 
