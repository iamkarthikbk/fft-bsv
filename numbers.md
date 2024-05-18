# This file contains the synth numbers.

![plt](./_artifacts/plot.png)

## Synthesis Results.

|     Transformation    	| Tables 	| Flops 	| DSPs 	| BRAMs 	|
|:---------------------:	|:------:	|:-----:	|:----:	|:-----:	|
|         unopt         	|   4840 	|  3356 	|   20 	|    14 	|
|       prim_only       	|   6075 	|  1024 	|    0 	|     0 	|
|       data_pack       	|   8280 	|  6058 	|   40 	|    16 	|
|         w_rom         	|   4840 	|  3356 	|   20 	|    14 	|
|       bfly_pipe2      	|   3877 	|  3079 	|   12 	|    18 	|
|       bfly_pipe4      	|   5621 	|  2064 	|    0 	|     0 	|
| bfly_pipe4, prim_fold 	|   2918 	|  2366 	|    7 	|    18 	|
|      stage_1fold      	|   3876 	|   518 	|   40 	|     0 	|
|       superfold       	|   3701 	|   522 	|   32 	|     0 	|

## Synthesis Observations.

1. Bluespec generated verilog, somehow, does not infer DSPs until I get to the folded architecture. I've validated that the * operand is indeed present in the generated verilog. im curious curious why.

2. the superfolded architecture does not give you much of an area reduction, because there's just too much multiplexing. this is evident from the bsv itself. still, some reduction can be observed.