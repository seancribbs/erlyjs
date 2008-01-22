%%%---------------------------------------------------------------------------------------
%%% @author     Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @copyright  2007 Roberto Saccon
%%% @doc        Javascript to Erlang compiler
%%% @end
%%%
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Roberto Saccon
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%%---------------------------------------------------------------------------------------
-module(erlyjs_compiler).
-author('rsaccon@gmail.com').

-export([compile/4]).

%%----------------------------------------------------------------------------------------
%% EOF = 0,                        /* end of file */
%% EOL = 1,                        /* end of line */
%% SEMI = 2,                       /* semicolon */
%% COMMA = 3,                      /* comma operator */
%% ASSIGN = 4,                     /* assignment ops (= += -= etc.) */
%% HOOK = 5, COLON = 6,            /* conditional (?:) */
%% OR = 7,                         /* logical or (||) */
%% AND = 8,                        /* logical and (&&) */
%% BITOR = 9,                      /* bitwise-or (|) */
%% BITXOR = 10,                    /* bitwise-xor (^) */
%% BITAND = 11,                    /* bitwise-and (&) */
%% EQOP = 12,                      /* equality ops (== !=) */
%% RELOP = 13,                     /* relational ops (< <= > >=) */
%% SHOP = 14,                      /* shift ops (<< >> >>>) */
%% PLUS = 15,                      /* plus */
%% MINUS = 16,                     /* minus */
%% STAR = 17, DIVOP = 18,          /* multiply/divide ops (* / %) */
%% UNARYOP = 19,                   /* unary prefix operator */
%% INC = 20, DEC = 21,             /* increment/decrement (++ --) */
%% DOT = 22,                       /* member operator (.) */
%% LB = 23, RB = 24,               /* left and right brackets */
%% LC = 25, RC = 26,               /* left and right curlies (braces) */
%% LP = 27, RP = 28,               /* left and right parentheses */
%% NAME = 29,                      /* identifier */
%% NUMBER = 30,                    /* numeric constant */
%% STRING = 31,                    /* string constant */
%% REGEXP = 32,                    /* RegExp constant */
%% PRIMARY = 33,                   /* true, false, null, this, super */
%% FUNCTION = 34,                  /* function keyword */
%% EXPORT = 35,                    /* export keyword */
%% IMPORT = 36,                    /* import keyword */
%% IF = 37,                        /* if keyword */
%% ELSE = 38,                      /* else keyword */
%% SWITCH = 39,                    /* switch keyword */
%% CASE = 40,                      /* case keyword */
%% DEFAULT = 41,                   /* default keyword */
%% WHILE = 42,                     /* while keyword */
%% DO = 43,                        /* do keyword */
%% FOR = 44,                       /* for keyword */
%% BREAK = 45,                     /* break keyword */
%% CONTINUE = 46,                  /* continue keyword */
%% IN = 47,                        /* in keyword */
%% VAR = 48,                       /* var keyword */
%% WITH = 49,                      /* with keyword */
%% RETURN = 50,                    /* return keyword */
%% NEW = 51,                       /* new keyword */
%% DELETE = 52,                    /* delete keyword */
%% DEFSHARP = 53,                  /* #n= for object/array initializers */
%% USESHARP = 54,                  /* #n# for object/array initializers */
%% TRY = 55,                       /* try keyword */
%% CATCH = 56,                     /* catch keyword */
%% FINALLY = 57,                   /* finally keyword */
%% THROW = 58,                     /* throw keyword */
%% INSTANCEOF = 59,                /* instanceof keyword */
%% DEBUGGER = 60,                  /* debugger keyword */
%% XMLSTAGO = 61,                  /* XML start tag open (<) */
%% XMLETAGO = 62,                  /* XML end tag open (</) */
%% XMLPTAGC = 63,                  /* XML point tag close (/>) */
%% XMLTAGC = 64,                   /* XML start or end tag close (>) */
%% XMLNAME = 65,                   /* XML start-tag non-final fragment */
%% XMLATTR = 66,                   /* XML quoted attribute value */
%% XMLSPACE = 67,                  /* XML whitespace */
%% XMLTEXT = 68,                   /* XML text */
%% XMLCOMMENT = 69,                /* XML comment */
%% XMLCDATA = 70,                  /* XML CDATA section */
%% XMLPI = 71,                     /* XML processing instruction */
%% AT = 72,                        /* XML attribute op (@) */
%% DBLCOLON = 73,                  /* namespace qualified name op (::) */
%% ANYNAME = 74,                   /* XML AnyName singleton (*) */
%% DBLDOT = 75,                    /* XML descendant op (..) */
%% FILTER = 76,                    /* XML filtering predicate op (.()) */
%% XMLELEM = 77,                   /* XML element node type (no token) */
%% XMLLIST = 78,                   /* XML list node type (no token) */
%% YIELD = 79,                     /* yield from generator function */
%% ARRAYCOMP = 80,                 /* array comprehension initialiser */
%% ARRAYPUSH = 81,                 /* array push within comprehension */
%% LEXICALSCOPE = 82,              /* block scope AST node label */
%% LET = 83,                       /* let keyword */
%% BODY = 84,                      /* synthetic body of function with
%%                                    destructuring formal parameters */
%% RESERVED,                       /* reserved keyword */
%% LIMIT                           /* domain size */
%%-----------------------------------------------------------------------------------------


-record(js_context, {
    scope = global}).
    
-record(ast_info, {
    export_asts = [],
    global_asts = []}).

%%--------------------------------------------------------------------
%% @spec (JsAst::tuple(), Mod::atom(), ) -> ok | {error, error::any()}
%% @doc
%% compiles JS AST to Erlang beam code
%% @end 
%%--------------------------------------------------------------------    
compile(JsAst, Module, Function, OutDir) ->
    case body_ast(JsAst, #js_context{}) of
        {error, _} = Err ->
            Err;        
        {FuncAsts, Info} ->
            GlobalFuncAst = Ast = erl_syntax:function(erl_syntax:atom(Function),
                [erl_syntax:clause([], none, Info#ast_info.global_asts)]),
                        
            ModuleAst = erl_syntax:attribute(erl_syntax:atom(module), [erl_syntax:atom(Module)]),
            
            ExportGlobal = erl_syntax:arity_qualifier(erl_syntax:atom(Function), erl_syntax:integer(0)),
            ExportAst = erl_syntax:attribute(erl_syntax:atom(export),
                [erl_syntax:list([ExportGlobal | Info#ast_info.export_asts])]),

            Forms = [erl_syntax:revert(X) || X <- [ModuleAst, ExportAst, GlobalFuncAst | FuncAsts]],
            
            io:format("TRACE ~p:~p Forms ~p~n",[?MODULE, ?LINE, Forms]),
            
            case compile:forms(Forms) of
                {ok, Module1, Bin} ->       
                    Path = filename:join([OutDir, atom_to_list(Module1) ++ ".beam"]),
                    case file:write_file(Path, Bin) of
                        ok ->
                            code:purge(Module1),
                            case code:load_binary(Module1, atom_to_list(Module1) ++ ".erl", Bin) of
                                {module, _} -> ok;
                                _ -> {error, "code reload failed"}
                            end;
                        {error, Reason} ->
                            {error, lists:concat(["beam generation failed (", Reason, "): ", Path])}
                    end;
                error ->
                    {error, "compilation failed"}
            end                   
    end.
        		
	
%%====================================================================
%% Internal functions
%%====================================================================    

body_ast({{'LC', _}, List}, Context) ->
	lists:foldl(fun
	        (X, {AccAst, AccInfo}) ->
	            case body_ast(X, Context) of
	                {Ast, Info} when is_list(Ast) ->                        
	                    {lists:merge(Ast, AccAst), info_merge(Info, AccInfo)};
	                {Ast, Info} ->                        
	                    {[Ast | AccAst], info_merge(Info, AccInfo)}
	            end
	    end,
	    {[], #ast_info{}},
	    lists:reverse(List));
	
body_ast({{'SEMI', _}, Val}, Context) ->
    body_ast(Val, Context);
    
body_ast({{'STRING', _}, Val}, _) ->
    %% TODO: switch to binaries
    {erl_syntax:string(Val), #ast_info{}};
    
body_ast({{'NUMBER', _}, Val}, _) ->
    %% TODO: either integer or float
    {erl_syntax:float(Val), #ast_info{}};
    
body_ast({{'NAME', _}, Val}, _) ->
    %% TODO: either integer or float
    {erl_syntax:variable(Val), #ast_info{}};
        
body_ast({{'STAR', _}, Left, Right}, Context) ->
    {AstInnerLeft,InfoLeft} = body_ast(Left, Context),
    {AstInnerRight,InfoRight} = body_ast(Right, Context),
    Info = info_merge(InfoLeft, InfoRight),
    {[AstInnerLeft, erl_syntax:operator("*"), AstInnerRight], Info};            
    
body_ast({{'FUNCTION', _}, Name, Args, Body}, Context) ->
    {AstInner,Info} = body_ast(Body, Context#js_context{scope=local}),
    Args1 = [erl_syntax:variable("Var" ++ atom_to_list(X)) || X <- Args],
    FuncName = "func_" ++ atom_to_list(Name),
    Ast = erl_syntax:function(erl_syntax:atom(FuncName),
        [erl_syntax:clause(Args1, none, AstInner)]),
    case Context#js_context.scope of
        global ->
            Export = erl_syntax:arity_qualifier(erl_syntax:atom(FuncName), erl_syntax:integer(length(Args))),
            Exports = [Export | Info#ast_info.export_asts], 
            {Ast, Info#ast_info{export_asts = Exports}};
        _ ->
            {Ast, Info}
    end;
        
body_ast({{'ASSIGN', _}, {{'NAME', _}, Name}, Right}, #js_context{scope=global}=Context) ->
    {AstInner,Info} = body_ast(Right, Context#js_context{scope=local}),
    Ast = erl_syntax:application(erl_syntax:atom(erlyjs_server), 
        erl_syntax:atom(set_var), [erl_syntax:atom(Name), AstInner]),
    
    {[], #ast_info{global_asts = [Ast]}};
    
body_ast({{'ASSIGN', _}, {{'NAME', _}, Name}, Right}, Context) ->
    {AstInner,Info} = body_ast(Right, Context),
    %% check if variable is local or global
    %% if local get new variable for name
    Ast = erl_syntax:match_expr(erl_syntax:variable("Var" ++ atom_to_list(Name)), AstInner),
    {Ast, Info};
    
body_ast({{'VAR', _}, List}, #js_context{scope=global}=Context) when is_list(List) ->
    %% init global variables
    {[], #ast_info{}};
    
body_ast({{'VAR', _}, List}, #js_context{}) when is_list(List) ->
    %% init local variables
    {[], #ast_info{}};    
        
body_ast({error, Reason}, Context) ->
    io:format("TRACE ~p:~p Error: ~p~n",[?MODULE, ?LINE, Reason]),
    {[], Reason};
        
body_ast(Other, Context) ->
    io:format("TRACE ~p:~p Other: ~p~n",[?MODULE, ?LINE, Other]),
	{[], #ast_info{}}.
	
	
info_merge(Info1, Info2) ->
    #ast_info{
        export_asts = lists:merge(Info1#ast_info.export_asts, Info2#ast_info.export_asts),
        global_asts = lists:merge(Info1#ast_info.global_asts, Info2#ast_info.global_asts)}.