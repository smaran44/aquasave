`timescale 1ns / 1ps

module tb_aquasave;

    // ---------------- Signals ----------------
    reg clk;
    reg reset;
    reg manual_clear;

    reg flow_in;
    reg flow_out;
    reg acoustic;

    wire valve;
    wire buzzer;
    wire [2:0] status;
    wire [2:0] zone_id;

    // ---------------- DUT ----------------
    aquasave_core #(
        .ZONE_ID(3'd1),
        .TIMER_LIMIT(20),     // Small window for fast sim
        .LEAK_TOLERANCE(2),
        .ACOU_THRESH(4)       // Acoustic persistence
    ) dut (
        .clk(clk),
        .reset(reset),
        .manual_clear(manual_clear),
        .flow_pulse_in(flow_in),
        .flow_pulse_out(flow_out),
        .acoustic_sensor(acoustic),
        .valve_close(valve),
        .alarm_buzzer(buzzer),
        .status(status),
        .zone_id(zone_id)
    );

    // ---------------- Clock ----------------
    always #5 clk = ~clk;   // 10ns period

    // ---------------- Test Sequence ----------------
    initial begin
        // Init
        clk = 0;
        reset = 1;
        manual_clear = 0;
        flow_in = 0;
        flow_out = 0;
        acoustic = 0;

        // ------------------------------------
        // RESET
        // ------------------------------------
        #40;
        reset = 0;

        // ------------------------------------
        // SCENARIO 1: NORMAL FLOW (SECURE)
        // in = out → no leak
        // ------------------------------------
        repeat (5) begin
            flow_in = 1; flow_out = 1; #10;
            flow_in = 0; flow_out = 0; #10;
        end
        #100;   // allow FSM evaluation

        // ------------------------------------
        // SCENARIO 2: LEAK DETECTION
        // in > out + tolerance
        // ------------------------------------
        reset = 1; #10; reset = 0;

        repeat (6) begin
            flow_in = 1;
            flow_out = 0;   // output slower
            #10;
            flow_in = 0;
            flow_out = 0;
            #10;
        end
        #100;   // FSM moves to LEAK → LOCKDOWN

        // ------------------------------------
        // MANUAL CLEAR (RECOVERY)
        // ------------------------------------
        manual_clear = 1; #10;
        manual_clear = 0;
        #40;

        // ------------------------------------
        // SCENARIO 3: PIPE BURST (ACOUSTIC)
        // sustained acoustic signal
        // ------------------------------------
        repeat (5) begin
            acoustic = 1;
            #10;
        end
        acoustic = 0;

        #50;    // FSM enters BURST → LOCKDOWN

        // ------------------------------------
        // MANUAL CLEAR AGAIN
        // ------------------------------------
        manual_clear = 1; #10;
        manual_clear = 0;
        #50;

        $finish;
    end

endmodule