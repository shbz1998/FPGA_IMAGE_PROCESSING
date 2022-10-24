module combinational_mult(product,multiplier,multiplicand);

   input [784-1:0]  multiplier, multiplicand;

   output        product;

 

   reg [1567:0]    product;

   reg           c;

   reg [784-1:0]    m;  

   integer       i;

 

   always @( multiplier or multiplicand )

     begin

//initialize

        product[1567:785] = 784'd0;

        product[1567:0] = multiplier;

        m = multiplicand;

        c = 1'd0;


         for(i=0; i<784; i=i+1)

           begin

    if(product[0]) 
    begin
        {c,product[1567:785]} = product[1567:785] + m ;
         

         product[784-1:0] = {c,product[1567:1]};

          c = 0;


                 end               

               else

                 begin

                      product[784-1:0] = {c,product[1567:1]};

                      c = 0;

                 end 



      end    //end of for loop..          

 

 

  end    

endmodule