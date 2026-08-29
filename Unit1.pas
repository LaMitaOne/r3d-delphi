unit Unit1;

{==============================================================================*
 *  Delphi VCL + Raylib + r3d + ModelEngine demo                                *
 *                                                                              *
 *  A classic "marble on a floor" demo that proves the whole pipeline works:    *
 *    - raylib window created and re-parented into a VCL form                   *
 *    - r3d renderer initialized on top of the raylib OpenGL context            *
 *    - TModelEngine driving Kraft physics (static floor + dynamic ball)        *
 *    - rendering done manually with raylib primitives (no mesh files needed)   *
 *                                                                              *
 *  Game loop is driven by a VCL TTimer (~60 ticks/sec) instead of a blocking   *
 *  raylib main loop, so the normal VCL message pump stays alive.               *
 *==============================================================================}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls,
  Raylib, RayMath, r3ddelphi,
  Kraft,          // Physics engine, required by ModelEngine
  ModelEngine;    // Actor/engine layer on top of r3d + Kraft

type
  TForm1 = class(TForm)
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FInitialized: Boolean;

    // --- Engine objects (nicely encapsulated) ---
    FEngine: TModelEngine;      // Owns all actors; frees them on Destroy
    FGroundActor: TModelActor;  // Static box = floor
    FBallActor: TModelActor;    // Dynamic sphere = the marble
  public
    procedure UpdateGame;
    procedure RenderGame;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
var
  RaylibWindowHWnd: HWND;
begin
  FInitialized := False;
  Self.KeyPreview := True;

  // ------------------------------------------------------------------
  // 1) Create the raylib window.
  //    Raylib creates its own top-level window with an OpenGL context;
  //    in the next step we re-parent it into this VCL form so it looks
  //    and behaves like an ordinary child control.
  // ------------------------------------------------------------------
  InitWindow(800, 600, 'Delphi VCL Raylib Marble Demo');
  SetTargetFPS(60);

  // ------------------------------------------------------------------
  // 2) Trap the raylib window inside the Delphi form:
  //      - find it by its title (must match the InitWindow title!)
  //      - turn it into a WS_CHILD of this form
  //      - resize it to fill the whole client area
  // ------------------------------------------------------------------
  RaylibWindowHWnd := FindWindow(nil, 'Delphi VCL Raylib Marble Demo');
  if RaylibWindowHWnd <> 0 then
  begin
    Winapi.Windows.SetParent(RaylibWindowHWnd, Self.Handle);
    SetWindowLong(RaylibWindowHWnd, GWL_STYLE, WS_CHILD or WS_VISIBLE);
    SetWindowPos(RaylibWindowHWnd, 0, 0, 0,
      Self.ClientWidth, Self.ClientHeight, SWP_NOZORDER);
  end;

  // ------------------------------------------------------------------
  // 3) Initialize the r3d renderer.
  //    Must happen AFTER the raylib window (and thus the OpenGL
  //    context) exists, because r3d builds on top of it.
  // ------------------------------------------------------------------
  R3D_Init(Self.ClientWidth, Self.ClientHeight);
  R3D_ENVIRONMENT_SET('background.color', GRAY);
  R3D_ENVIRONMENT_SET('ambient.color', LIGHTGRAY);

  // ------------------------------------------------------------------
  // 4) Create the model engine (r3d rendering + Kraft physics)
  //    and set world gravity.
  // ------------------------------------------------------------------
  FEngine := TModelEngine.Create;
  FEngine.Physics.Gravity.x := 0.0;
  FEngine.Physics.Gravity.y := -9.81;   // Earth gravity, -Y is down
  FEngine.Physics.Gravity.z := 0.0;

  // ------------------------------------------------------------------
  // 5) Create the actors.
  //    Passing '' as the model path means "no mesh file": these actors
  //    are pure physics bodies which we draw manually with raylib
  //    primitives in RenderGame. This keeps the demo asset-free.
  // ------------------------------------------------------------------

  // Static floor: 30 x 1 x 30 box, top surface at y = 0
  FGroundActor := TModelActor.Create('', FEngine, kstBox,
    Vector3Create(30.0, 1.0, 30.0), krbtSTATIC);
  FGroundActor.Position := Vector3Create(0.0, -0.5, 0.0);
  FGroundActor.Friction := 0.5;
  FGroundActor.Restitution := 0.2;

  // Dynamic marble: sphere, spawns 5 units above the floor
  FBallActor := TModelActor.Create('', FEngine, kstSphere,
    Vector3Create(1.0, 1.0, 1.0), krbtDYNAMIC);
  FBallActor.Position := Vector3Create(0.0, 5.0, 0.0);
  FBallActor.Friction := 0.5;
  FBallActor.Restitution := 0.6;
  FBallActor.Mass := 1.0;

  // Drive the game loop from a VCL timer (~60 Hz)
  Timer1.Interval := 16;
  Timer1.Enabled := True;

  FInitialized := True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if FInitialized then
  begin
    Timer1.Enabled := False;
    FEngine.Free;   // Frees all registered actors automatically
    R3D_Close();    // Shut down the r3d renderer
    CloseWindow();  // Destroy the raylib window / GL context
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  // If the embedded raylib window was closed, stop the loop gracefully
  if WindowShouldClose() then
  begin
    Timer1.Enabled := False;
    Application.Terminate;
    Exit;
  end;

  UpdateGame;
  RenderGame;
end;

procedure TForm1.UpdateGame;
var
  Dt: Single;
  Impulse: TVector3;
  Power: Single;
  CurrentVel: TKraftVector3;
  NewVel: TKraftVector3;
  ZeroVel: TKraftVector3;
  SpeedSq: Single;
begin
  // Delta time since the last frame (in seconds)
  Dt := GetFrameTime();

  // ------------------------------------------------------------------
  // 1) Tick the physics world. This also syncs all actor positions
  //    from their rigid bodies.
  // ------------------------------------------------------------------
  FEngine.Update(Dt);

  // ------------------------------------------------------------------
  // 2) Velocity handling for the marble: horizontal damping + respawn.
  // ------------------------------------------------------------------
  if Assigned(FBallActor.Body) then
  begin
    // Wake the body up so velocity changes are picked up reliably
    FBallActor.Body.SetToAwake;

    // Read current velocity
    CurrentVel := FBallActor.Body.LinearVelocity;

    // Damping: keep 98% of horizontal speed each frame.
    // Vertical speed (falling) is left untouched.
    NewVel.x := CurrentVel.x * 0.98;
    NewVel.y := CurrentVel.y;
    NewVel.z := CurrentVel.z * 0.98;
    FBallActor.Body.LinearVelocity := NewVel;

    // Fell off the world? Respawn above the floor.
    if FBallActor.Position.y < -20.0 then
    begin
      // Reset via the Position property (its setter syncs the body)
      FBallActor.Position := Vector3Create(0.0, 5.0, 0.0);

      // Zero out all motion
      ZeroVel.x := 0; ZeroVel.y := 0; ZeroVel.z := 0;
      FBallActor.Body.LinearVelocity := ZeroVel;
      FBallActor.Body.AngularVelocity := ZeroVel;
    end;
  end;

  // ------------------------------------------------------------------
  // 3) Player input via WinAPI GetKeyState.
  //    (Used instead of raylib IsKeyDown because the raylib window is
  //    a child window inside a VCL form - VCL may steal the focus.)
  //    The $8000 bit test checks whether the key is currently down.
  // ------------------------------------------------------------------
  Impulse := Vector3Create(0, 0, 0);
  Power := 150.0 * Dt;   // Frame-rate independent impulse strength

  if (GetKeyState(VK_RIGHT) and $8000) <> 0 then Impulse.x := Power;
  if (GetKeyState(VK_LEFT)  and $8000) <> 0 then Impulse.x := -Power;
  if (GetKeyState(VK_UP)    and $8000) <> 0 then Impulse.z := -Power;
  if (GetKeyState(VK_DOWN)  and $8000) <> 0 then Impulse.z := Power;

  if (Impulse.x <> 0) or (Impulse.z <> 0) then
  begin
    if Assigned(FBallActor.Body) then
    begin
      CurrentVel := FBallActor.Body.LinearVelocity;
      SpeedSq := (CurrentVel.x * CurrentVel.x) + (CurrentVel.z * CurrentVel.z);

      // Only accelerate while below the speed limit (15 units/sec)
      if SpeedSq < 225.0 then
        FBallActor.ApplyImpulse(Impulse);
    end;
  end;
end;

procedure TForm1.RenderGame;
var
  Camera: TCamera3D;
begin
  // Simple follow camera: fixed offset, always looking at the marble
  Camera.position := Vector3Create(0.0, 10.0, 15.0);
  Camera.target := FBallActor.Position;
  Camera.up := Vector3Create(0.0, 1.0, 0.0);
  Camera.fovy := 45.0;
  Camera.projection := CAMERA_PERSPECTIVE;

  BeginDrawing();
    ClearBackground(RAYWHITE);

    BeginMode3D(Camera);
      // No mesh files are loaded, so we draw the actors manually
      // with raylib primitive shapes:

      // 1) Floor
      DrawCube(FGroundActor.Position, 30.0, 1.0, 30.0, DARKGRAY);
      DrawCubeWires(FGroundActor.Position, 30.0, 1.0, 30.0, BLACK);

      // 2) Marble
      DrawSphere(FBallActor.Position, 1.0, RED);
      DrawSphereWires(FBallActor.Position, 1.0, 16, 16, MAROON);
    EndMode3D();
  EndDrawing();
end;

end.
