typedef struct packed{
    logic retire1;
    logic retire2;
    logic retire3;
    logic [5:0]archIdex1;
    logic [6:0]archTag1;
    logic [5:0]archIdex2;
    logic [6:0]archTag2;
    logic [5:0]archIdex3;
    logic [6:0]archTag3; 
}archMap_retire_input;

typedef struct packed{
    logic valid1;
    logic valid2;
    logic valid3;
    logic [5:0]archIdex1;
    logic [5:0]archIdex2;
    logic [5:0]archIdex3; 
}archMap_index_input;

typedef struct packed{
    logic valid1;
    logic valid2;
    logic valid3;
    logic [6:0]archTag1;
    logic [6:0]archTag2;
    logic [6:0]archTag3; 
}archMap_index_output;
