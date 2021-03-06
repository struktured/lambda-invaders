open CamomileLibrary.UChar
open LTerm_key
open LTerm_geom
open LTerm_widget
open L_utils

type alien = {index:int;
              spot:(int * int);
              drawing_char:CamomileLibrary.UChar.t}

class game_frame exit_ show_help show_endgame =
  object(self)
    inherit LTerm_widget.frame as super

    val mutable init = false
    val mutable previous_location = None
    val mutable rockets = [||]
    val mutable aliens = [||]
    val hits = ref 0
    val go_down = ref 0
    (* 0 is down, 1 is left, 2 is right *)
    val direction = ref 1
    val max_cols = ref 0
    val mutable current_event = None

    val defender_style = LTerm_style.({bold = None;
                                       underline = None;
                                       blink = None;
                                       reverse = None;
                                       foreground = Some lblue;
                                       background = Some lgreen})

    val rocket_style = LTerm_style.({bold = None;
                                     underline = None;
                                     blink = None;
                                     reverse = None;
                                     foreground = Some lred;
                                     background = None})

    (* Not sure why this doesn't compile without the explicit type
       signature *)
    method queue_event_draw (event : Lwt_engine.event) =
      current_event <- Some event;
      self#queue_draw

    method draw ctx focused_widget =
      (* Calling super just for that frame wrapping, aka the |_| *)
      (* Make sure that row1 is smaller than row2
         and that col1 is smaller than col2, it goes:
                          row1
                      col1    col2
                          row2 *)
      LTerm_draw.clear ctx;
      super#draw ctx focused_widget;
      LTerm_draw.draw_string ctx 0 0 ("Hits: " ^ (string_of_int !hits));
      LTerm_draw.draw_string ctx 13 0 ~style:LTerm_style.({bold = None;
                                                    underline = None;
                                                    blink = Some true;
                                                    reverse = None;
                                                    foreground = Some lyellow;
                                                    background = None})
        "Game Over Line";

      if not init
      then
        begin
          let this_size = LTerm_draw.size ctx in
          init <- true;
          max_cols := this_size.cols;

          previous_location <- Some {row = this_size.rows - 1;
                                     col = (this_size.cols / 2)};

          let ctx_ = LTerm_draw.sub ctx {row1 = this_size.rows - 2;
                                        col1 = (this_size.cols / 2);
                                        row2 = this_size.rows - 1;
                                        col2 = (this_size.cols / 2) + 1} in

          (* NOTE Drawing outside of your context is a no op *)
          LTerm_draw.draw_string ctx_ 0 0 "λ";
          (* TODO Pick smarter values as a function of terminal size? *)

          (* Rows*)
          for i = 3 to 10 do
            (* Columns *)
            for j = 10 to 44 do
              if (i mod 2 > 0) && (j mod 2 > 0)
              then
                aliens <- Array.append [|{index = Array.length aliens;
                                          spot = (i, j);
                                          drawing_char = (of_int 128125)}|] aliens;
              LTerm_draw.draw_char ctx i j (of_int 128125)
            done
          done

        end
      else
        if (fst (Array.get aliens 51).spot) = 12
        then (match current_event with
             | Some e ->
                Lwt_engine.stop_event e;
                self#show_endgame_modal ()
             | None -> ());

        begin
          (* Drawing the lambda defender *)
          (match previous_location with
            | Some c ->
                let ctx = LTerm_draw.sub ctx {row1 = c.row - 1;
                                              col1 = c.col;
                                              row2 = c.row ;
                                              col2 = c.col + 1 } in
                LTerm_draw.clear ctx;
                LTerm_draw.draw_styled ctx 0 0
                  ~style:defender_style
                  (LTerm_text.of_string "λ")
            | None -> ());

          begin
          (* Aliens drawing *)
            let cp = Array.copy aliens in
            match !direction with
            (* 2 is right, 1 is left, 0 is down *)
            | 0 ->
              Array.iter (fun a ->
                          match a with
                          | {index = index; spot = (i, j); drawing_char = d} as p ->
                             Array.set aliens index {p with spot = (i + 1, j)};
                             LTerm_draw.draw_char ctx 0 0 d)
                         cp;
               go_down := !go_down mod 3;
               direction := !direction + 1;
            | 1 ->
              Array.iter (fun a ->
                          match a with
                          | {index = index; spot = (i, j); drawing_char = d} as p -> 
                             Array.set aliens index {p with spot = (i, j - 1)};
                             LTerm_draw.draw_char ctx i (j - 1) d)
                         cp;
            | 2 ->
              Array.iter (fun a ->
                          match a with
                          | {index = index; spot = (i, j); drawing_char = d} as p -> 
                             Array.set aliens index {p with spot = (i, j + 1)};
                             LTerm_draw.draw_char ctx i (j + 1) d)
                         cp;
            | _ -> ();

                   (* Change directions *)
          end ;
          (* Setting the direction *)
          if !go_down = 3
          then
            direction := 0;
          
          begin
            match Array.get aliens 0 with
            | {index = index; spot = (row, column)} -> 
              if column = 1
              then
                (direction := 2;
                 go_down := !go_down + 1)
              else (match Array.get aliens ((Array.length aliens) - 1) with
                    | {index = index; spot = (row, column)} -> 
                       if (column = ((LTerm_draw.size ctx).cols - 2))
                       then
                         (direction := 1;
                          go_down := !go_down +1);
                   )
          end;

          (* Rockets drawing *)
          Array.iter (fun (index, roc) ->
              let ctx = LTerm_draw.sub ctx {row1 = roc.row - 1;
                                            col1 = roc.col;
                                            row2 = roc.row;
                                            col2 = roc.col + 1} in
              if roc.row > 1 then
                begin
                  Array.iter (fun r ->
                              match r with
                              | {index = index; spot = (row, column); drawing_char = d} as p -> 
                                 if (roc.row = row) &&
                                    (roc.col = column) &&
                                    not (eq d (of_char ' '))
                                 then
                                   begin 
                                     Array.set aliens index {p with drawing_char = (of_char ' ' )};
                                     hits := !hits + 1
                                   end
                    )
                    aliens;
                  LTerm_draw.draw_styled ctx 0 0 ~style:rocket_style
                    (LTerm_text.of_string "↥");
                  Array.set rockets index (index , {roc with row = roc.row - 1})
                end
              else
                  Array.set rockets index (index , roc))
                     (* Need the copy otherwise mutating the array as
                        you're iterating over it, a bug *)
                     (Array.copy rockets)
        end

    method show_endgame_modal () =
      show_endgame ()

    method move_left =
      match previous_location with 
      | Some p ->
         if p.col > 2 then
           previous_location <- Some {p with col = p.col - 2}
      | None -> ()

    method move_right =
      match previous_location with 
        | Some p ->
          if p.col < !max_cols - 3 then
          previous_location <- Some {p with col = p.col + 2}
        | None -> ()

    method fire_rocket =
      match previous_location with 
        | Some p ->
          rockets <- Array.append [|(Array.length rockets, p)|] rockets
        | None -> ();
      self#queue_draw;

    initializer
      self#on_event
        (function
          | LTerm_event.Key {code = Left} ->
            self#move_left;
            true
          | LTerm_event.Key {code = Right} ->
            self#move_right;
            true
          | LTerm_event.Key
              {code = LTerm_key.Char ch}
            when ch = of_char ' ' ->
            self#fire_rocket;
            true
          | LTerm_event.Key
              {meta = true; code = LTerm_key.Char ch}
            when ch = of_char 'h' ->
            show_help ();
            true
          | LTerm_event.Key
              {code = LTerm_key.Char ch}
            when ch = of_char 'q' ->
            exit_ ();
            true
          | _ -> false)
  end
