`timescale 1ns / 1ps

module aquasave_core #(
    parameter ZONE_ID       = 3'd1,      // Zonal abstraction
    parameter TIMER_LIMIT   = 1000,       // Flow window
    parameter LEAK_TOLERANCE= 2,          // Pulse tolerance
    parameter ACOU_THRESH   = 4           // Acoustic persistence cycles
)(
    input  wire clk,
    input  wire reset,
    input  wire manual_clear,

    // Sensors
    input  wire flow_pulse_in,
    input  wire flow_pulse_out,
    input  wire acoustic_sensor,

    // Actuators
    output reg  valve_close,
    output reg  alarm_buzzer,
    output reg  [2:0] status,     // 001=OK, 010=LEAK, 100=BURST
    output reg  [2:0] zone_id
);

    // ---------------- FSM STATES ----------------
    localparam IDLE     = 3'd0;
    localparam MONITOR  = 3'd1;
    localparam LEAK     = 3'd2;
    localparam BURST    = 3'd3;
    localparam LOCKDOWN = 3'd4;

    reg [2:0] state, next_state;

    // ---------------- Synchronizers ----------------
    reg [1:0] sync_in, sync_out, sync_acou;
    always @(posedge clk) begin
        sync_in   <= {sync_in[0], flow_pulse_in};
        sync_out  <= {sync_out[0], flow_pulse_out};
        sync_acou <= {sync_acou[0], acoustic_sensor};
    end

    wire in_rise  = (sync_in  == 2'b01);
    wire out_rise = (sync_out == 2'b01);

    // ---------------- Counters ----------------
    reg [31:0] timer;
    reg [15:0] count_in, count_out;
    reg [3:0]  acoustic_cnt;

    // ---------------- FSM SEQUENTIAL ----------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // ---------------- FSM COMBINATIONAL ----------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    next_state = MONITOR;

            MONITOR: begin
                if (acoustic_cnt >= ACOU_THRESH)
                    next_state = BURST;
                else if (timer >= TIMER_LIMIT &&
                        (count_in > (count_out + LEAK_TOLERANCE)))
                    next_state = LEAK;
            end

            LEAK:     next_state = LOCKDOWN;
            BURST:    next_state = LOCKDOWN;

            LOCKDOWN: begin
                if (manual_clear)
                    next_state = IDLE;
            end
        endcase
    end

    // ---------------- OUTPUT & DATA LOGIC ----------------
    always @(posedge clk) begin
        // Defaults
        valve_close  <= 0;
        alarm_buzzer <= 0;
        status       <= 3'b001;
        zone_id      <= ZONE_ID;

        case (state)
            IDLE: begin
                timer        <= 0;
                count_in     <= 0;
                count_out    <= 0;
                acoustic_cnt <= 0;
            end

            MONITOR: begin
                if (in_rise)  count_in  <= count_in  + 1;
                if (out_rise) count_out <= count_out + 1;

                if (sync_acou[1])
                    acoustic_cnt <= acoustic_cnt + 1;
                else
                    acoustic_cnt <= 0;

                timer <= timer + 1;
            end

            LEAK: begin
                valve_close  <= 1;
                alarm_buzzer <= 1;
                status       <= 3'b010; // Leak
            end

            BURST: begin
                valve_close  <= 1;
                alarm_buzzer <= 1;
                status       <= 3'b100; // Burst
            end

            LOCKDOWN: begin
                valve_close  <= 1;
                alarm_buzzer <= 1;
            end
        endcase
    end

endmodule
