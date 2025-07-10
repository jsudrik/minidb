%{
#include "parser.tab.h"
#include <string.h>
#include <ctype.h>
%}

%option case-insensitive

%%
"SELECT"    { return SELECT; }
"FROM"      { return FROM; }
"WHERE"     { return WHERE; }
"INSERT"    { return INSERT; }
"INTO"      { return INTO; }
"VALUES"    { return VALUES; }
"UPDATE"    { return UPDATE; }
"SET"       { return SET; }
"DELETE"    { return DELETE; }
"CREATE"    { return CREATE; }
"DROP"      { return DROP; }
"TABLE"     { return TABLE; }
"INDEX"     { return INDEX; }
"ON"        { return ON; }
"USING"     { return USING; }
"INT"       { return INT_TYPE; }
"BIGINT"    { return BIGINT_TYPE; }
"FLOAT"     { return FLOAT_TYPE; }
"CHAR"      { return CHAR_TYPE; }
"VARCHAR"   { return VARCHAR_TYPE; }
"BTREE"     { return BTREE; }
"HASH"      { return HASH; }
"DESCRIBE"  { return DESCRIBE; }
"DESC"      { return DESCRIBE; }
"SHOW"      { return SHOW; }
"TABLES"    { return TABLES; }
"BEGIN"     { return BEGIN_TXN; }
"COMMIT"    { return COMMIT; }
"ROLLBACK"  { return ROLLBACK; }
"AND"       { return AND; }
"OR"        { return OR; }
[a-zA-Z_][a-zA-Z0-9_]* { 
    yylval.str = strdup(yytext); 
    return IDENTIFIER; 
}
[0-9]+      { yylval.num = atoi(yytext); return NUMBER; }
[0-9]*\.[0-9]+ { yylval.fval = atof(yytext); return FLOAT_NUM; }
'[^']*'     { 
    yylval.str = strdup(yytext + 1); 
    yylval.str[strlen(yylval.str) - 1] = '\0'; 
    return STRING; 
}
"="         { return EQ; }
"<>"        { return NE; }
"!="        { return NE; }
"<"         { return LT; }
">"         { return GT; }
"<="        { return LE; }
">="        { return GE; }
"("         { return LPAREN; }
")"         { return RPAREN; }
","         { return COMMA; }
";"         { return SEMICOLON; }
"*"         { return ASTERISK; }
[ \t\n]+    { /* ignore whitespace */ }
.           { return yytext[0]; }
%%

int yywrap() { return 1; }