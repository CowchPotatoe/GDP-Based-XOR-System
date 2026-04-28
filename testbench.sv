`timescale 1ns/1ps

module testb;
	wire        displayRes;
	wire [7:0]  sum;
	reg  [7:0]  nIn;
	reg         start, restart, clk;
	localparam vectlen = 20;
  reg [7:0] vect [0:vectlen-1];
  reg [7:0]  expected, X, Y;
	integer i;

	// DUT 
  GDP_mod dut (
    .sum(sum),
    .start(start),
    .restart(restart),
    .clk(clk),
    .n(nIn),
    .done(displayRes)
  );

  // Clock generator
  initial begin
    clk = 1'b0;
    forever #2 clk = ~clk; 
  end
  // Start pulse (active-low)
  task pulse_start;
    begin
      start = 1'b1; @(posedge clk);
      start = 1'b0; @(posedge clk);
      start = 1'b1;
    end
  endtask

  // Restart pulse (active-low)
  task pulse_restart;
    begin
      restart = 1'b1; @(posedge clk);
      restart = 1'b0; @(posedge clk);
      restart = 1'b1;
    end
  endtask

  
  initial begin
    start = 1'b1;
    restart = 1'b1;
    nIn = 8'h00;
    // Open test vector file
	  $readmemh("testvector.txt", vect);
	  pulse_restart();
	
	for(i = 0; i < 20; i = i + 2) begin
		pulse_start();
      X = vect[i];
      Y = vect[i+1];

      nIn = X;
      @(posedge clk);
      nIn = Y;
      
		wait(displayRes === 1'b1);
		@(posedge clk);
    expected = X^Y;

    // Display result
    if (sum === expected)
      $display("X=%02h Y=%02h Expected=%02h Got=%02h PASS", X, Y, expected, sum);
    else
      $display("X=%02h Y=%02h Expected=%02h Got=%02h FAIL", X, Y, expected, sum);
      			
		pulse_restart();
		wait(displayRes === 1'b0);
	end
  $finish;
  end
endmodule