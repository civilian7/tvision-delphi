/* ============================================================
 *  tvision_c.h
 *  C ABI wrapper for the magiblot/tvision C++ framework.
 *  Designed to be consumed from Delphi (or any C-compatible
 *  language) via a DLL.
 * ============================================================
 */
#ifndef TVISION_C_H
#define TVISION_C_H

#include <stddef.h>
#include <stdint.h>

#ifdef _WIN32
#  ifdef TVCAPI_BUILD
#    define TVCAPI __declspec(dllexport)
#  else
#    define TVCAPI __declspec(dllimport)
#  endif
#  define TVCALL __stdcall
#else
#  define TVCAPI
#  define TVCALL
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ---- Opaque handles -------------------------------------- */
typedef void* TvHandle;      /* generic TView*       */
typedef void* TvAppHandle;
typedef void* TvViewHandle;
typedef void* TvDialogHandle;
typedef void* TvWindowHandle;
typedef void* TvMenuHandle;
typedef void* TvStatusHandle;

/* ---- Types ----------------------------------------------- */
typedef struct TvRect {
    int16_t ax, ay, bx, by;
} TvRect;

typedef struct TvEvent {
    uint16_t what;          /* evCommand etc.  */
    uint16_t command;       /* command id      */
    int32_t  infoInt;
    void*    infoPtr;
} TvEvent;

/* ---- Constants ------------------------------------------- */
/* Event types */
#define TV_evNothing       0x0000
#define TV_evMouseDown     0x0001
#define TV_evMouseUp       0x0002
#define TV_evMouseMove     0x0004
#define TV_evMouseAuto     0x0008
#define TV_evKeyDown       0x0010
#define TV_evCommand       0x0100
#define TV_evBroadcast     0x0200

/* Standard commands */
#define TV_cmValid         0
#define TV_cmQuit          1
#define TV_cmError         2
#define TV_cmMenu          3
#define TV_cmClose         4
#define TV_cmZoom          5
#define TV_cmResize        6
#define TV_cmNext          7
#define TV_cmPrev          8
#define TV_cmHelp          9
#define TV_cmOK            10
#define TV_cmCancel        11
#define TV_cmYes           12
#define TV_cmNo            13
#define TV_cmDefault       14

/* Button flags */
#define TV_bfNormal        0x00
#define TV_bfDefault       0x01
#define TV_bfLeftJust      0x02
#define TV_bfBroadcast     0x04
#define TV_bfGrabFocus     0x08

/* Message box options */
#define TV_mfWarning       0x0000
#define TV_mfError         0x0001
#define TV_mfInformation   0x0002
#define TV_mfConfirmation  0x0003
#define TV_mfYesButton     0x0100
#define TV_mfNoButton      0x0200
#define TV_mfOKButton      0x0400
#define TV_mfCancelButton  0x0800
#define TV_mfYesNoCancel   (TV_mfYesButton|TV_mfNoButton|TV_mfCancelButton)
#define TV_mfOKCancel      (TV_mfOKButton|TV_mfCancelButton)

/* Window flags */
#define TV_wfMove          0x01
#define TV_wfGrow          0x02
#define TV_wfClose         0x04
#define TV_wfZoom          0x08

/* Status item special key codes (a few common ones) */
#define TV_kbNoKey         0x0000
#define TV_kbAltX          0x2D00
#define TV_kbF10           0x4400
#define TV_kbAltF3         0x6800

/* hcNoContext */
#define TV_hcNoContext     0

/* ---- Callback signatures --------------------------------- */
/* Returns 1 if event was handled (and should be cleared).
 * appData is the opaque pointer supplied to TvApp_Create.   */
typedef int  (TVCALL *TvEventHandler)(const TvEvent* ev, void* appData);

/* Build menu bar inside the given rect; return menu handle
 * (created via TvMenu_Begin/AddItem/End).                   */
typedef TvMenuHandle   (TVCALL *TvMenuBuilder)(const TvRect* r, void* appData);
typedef TvStatusHandle (TVCALL *TvStatusBuilder)(const TvRect* r, void* appData);

/* Idle hook (called from idle()). Returns nothing.          */
typedef void (TVCALL *TvIdleHandler)(void* appData);

/* ---- Application lifecycle ------------------------------- */
TVCAPI TvAppHandle TVCALL TvApp_Create(
    TvMenuBuilder    menuBuilder,    /* may be NULL */
    TvStatusBuilder  statusBuilder,  /* may be NULL */
    TvEventHandler   eventHandler,   /* may be NULL */
    TvIdleHandler    idleHandler,    /* may be NULL */
    void*            appData);

TVCAPI void TVCALL TvApp_Run(TvAppHandle app);
TVCAPI void TVCALL TvApp_Suspend(TvAppHandle app);
TVCAPI void TVCALL TvApp_Resume(TvAppHandle app);
TVCAPI void TVCALL TvApp_Destroy(TvAppHandle app);

/* Returns the desktop's TView* */
TVCAPI TvViewHandle TVCALL TvApp_GetDeskTop(TvAppHandle app);

/* Get desktop bounds */
TVCAPI void TVCALL TvApp_GetExtent(TvAppHandle app, TvRect* outRect);

/* Insert a top-level view (e.g. TWindow) into the desktop   */
TVCAPI void TVCALL TvApp_InsertWindow(TvAppHandle app, TvWindowHandle win);

/* Execute a modal view (dialog) on the desktop;
 * returns the command that ended the modal.                 */
TVCAPI uint16_t TVCALL TvApp_ExecView(TvAppHandle app, TvViewHandle view);

/* Destroy a view via TObject::destroy.  If the view still has a
 * parent owner, it is removed first so the underlying area is
 * repainted (otherwise frame artifacts are left on screen).    */
TVCAPI void TVCALL TvView_Destroy(TvViewHandle view);

/* Force a single view to repaint.            */
TVCAPI void TVCALL TvView_Redraw(TvViewHandle view);
/* Force the whole application (desktop+menus+status) to repaint. */
TVCAPI void TVCALL TvApp_Redraw(TvAppHandle app);

/* ---- Menus ----------------------------------------------- */
/* The builder callback should call TvMenu_BeginBar with the
 * rect, then issue a sequence of AddSub / AddItem / AddLine
 * / EndSub calls and finally TvMenu_FinishBar to obtain the
 * TMenuBar* handle to return.                               */
TVCAPI void           TVCALL TvMenu_BeginBar(const TvRect* r);
TVCAPI void           TVCALL TvMenu_AddSub(const char* title, uint16_t hotKey);
TVCAPI void           TVCALL TvMenu_EndSub(void);
TVCAPI void           TVCALL TvMenu_AddItem(const char* title,
                                            uint16_t command,
                                            uint16_t keyCode,
                                            const char* hint);
TVCAPI void           TVCALL TvMenu_AddLine(void);
TVCAPI TvMenuHandle   TVCALL TvMenu_FinishBar(void);

/* ---- Status line ---------------------------------------- */
TVCAPI void            TVCALL TvStatus_Begin(const TvRect* r);
TVCAPI void            TVCALL TvStatus_AddItem(const char* text,
                                               uint16_t keyCode,
                                               uint16_t command);
TVCAPI TvStatusHandle  TVCALL TvStatus_Finish(void);

/* ---- Dialogs / Windows ---------------------------------- */
TVCAPI TvDialogHandle TVCALL TvDialog_Create(const TvRect* r, const char* title);
TVCAPI TvWindowHandle TVCALL TvWindow_Create(const TvRect* r, const char* title,
                                             int16_t windowNumber);

TVCAPI void TVCALL TvView_Insert(TvViewHandle parent, TvViewHandle child);
TVCAPI void TVCALL TvView_SetData(TvViewHandle view, const void* data);
TVCAPI void TVCALL TvView_GetData(TvViewHandle view, void* data);

/* ---- Standard widgets (return a TView* handle to insert) */
TVCAPI TvViewHandle TVCALL TvStaticText_Create(const TvRect* r, const char* text);

TVCAPI TvViewHandle TVCALL TvButton_Create(const TvRect* r,
                                           const char* title,
                                           uint16_t command,
                                           uint16_t flags);

TVCAPI TvViewHandle TVCALL TvLabel_Create(const TvRect* r,
                                          const char* text,
                                          TvViewHandle linkedView);

/* maxLen bytes max input. Use TvView_GetData to read text out. */
TVCAPI TvViewHandle TVCALL TvInputLine_Create(const TvRect* r, int16_t maxLen);

/* items: array of NUL-terminated strings, count = number of items */
TVCAPI TvViewHandle TVCALL TvCheckBoxes_Create(const TvRect* r,
                                               const char* const* items,
                                               int count);
TVCAPI TvViewHandle TVCALL TvRadioButtons_Create(const TvRect* r,
                                                 const char* const* items,
                                                 int count);

/* ---- Messageboxes / inputbox ---------------------------- */
TVCAPI uint16_t TVCALL TvMessageBox(const char* msg, uint16_t options);
TVCAPI uint16_t TVCALL TvInputBox(const char* title,
                                  const char* label,
                                  char* buffer,
                                  int bufferSize);

/* ---- Editor (TEditWindow) ------------------------------- */
/* Window number -1 means wnNoNumber. fileName may be NULL for an
 * untitled new buffer.                                     */
TVCAPI TvWindowHandle TVCALL TvEditWindow_Create(const TvRect* r,
                                                 const char* fileName,
                                                 int16_t windowNumber);

/* ---- Custom view (Delphi-side draw / event) ------------- */
typedef void (TVCALL *TvDrawCallback)(TvViewHandle view, void* userData);
typedef int  (TVCALL *TvViewEventCallback)(TvViewHandle view,
                                           const TvEvent* ev,
                                           void* userData);

/* Creates a TView subclass that forwards draw() to drawCb and
 * handleEvent() to eventCb.  paletteBytes/paletteLen are copied
 * (may be NULL).  Caller must keep userData alive.        */
TVCAPI TvViewHandle TVCALL TvCustomView_Create(
    const TvRect*       r,
    TvDrawCallback      drawCb,
    TvViewEventCallback eventCb,
    const char*         paletteBytes,
    int                 paletteLen,
    void*               userData);

/* ---- View drawing primitives (call from drawCb) --------- */
TVCAPI void  TVCALL TvView_GetSize(TvViewHandle v, int* outCx, int* outCy);
/* Resolve a palette index into an attribute byte (foreground+bg). */
TVCAPI uint8_t TVCALL TvView_GetColor(TvViewHandle v, uint16_t paletteIndex);
TVCAPI void  TVCALL TvView_WriteText(TvViewHandle v, int x, int y,
                                     const char* text, uint8_t attr);
TVCAPI void  TVCALL TvView_WriteFill(TvViewHandle v, int x, int y,
                                     int w, int h, char ch, uint8_t attr);

/* ---- Window options helpers ----------------------------- */
TVCAPI void TVCALL TvView_SetOptionCentered(TvViewHandle v);

/* ---- Command enable/disable ----------------------------- */
TVCAPI void TVCALL TvApp_EnableCommand(uint16_t command);
TVCAPI void TVCALL TvApp_DisableCommand(uint16_t command);

/* ---- File dialog ---------------------------------------- */
#define TV_fdOKButton      0x0001
#define TV_fdOpenButton    0x0002
#define TV_fdReplaceButton 0x0004
#define TV_fdClearButton   0x0008
#define TV_fdHelpButton    0x0010
#define TV_fdNoLoadDir     0x0100

#define TV_cmFileOpen   1001  /* dialog returned with Open    */
#define TV_cmFileReplace 1002 /* dialog returned with Replace */
#define TV_cmFileClear   1003 /* dialog returned with Clear   */
#define TV_cmFileInit    1004

TVCAPI TvDialogHandle TVCALL TvFileDialog_Create(
    const char* wildCard,
    const char* title,
    const char* inputName,
    uint16_t    options,
    uint8_t     histId);

/* Copy chosen filename into provided buffer (NUL-terminated).
 * Returns the number of bytes written excluding NUL.       */
TVCAPI int TVCALL TvFileDialog_GetFileName(TvDialogHandle dlg,
                                           char* buffer, int bufferSize);

/* ---- Window management ---------------------------------- */
/* Replace the menu bar at runtime (used e.g. by mmenu).    */
TVCAPI void TVCALL TvApp_SetMenuBar(TvAppHandle app, TvMenuHandle newMenu);

/* Tile / cascade desktop windows. */
TVCAPI void TVCALL TvApp_DesktopTile(TvAppHandle app);
TVCAPI void TVCALL TvApp_DesktopCascade(TvAppHandle app);

/* Send a broadcast message to the desktop. */
TVCAPI void TVCALL TvApp_BroadcastCmd(TvAppHandle app, uint16_t command);

/* Get number of windows on the desktop. */
TVCAPI int TVCALL TvApp_DesktopWindowCount(TvAppHandle app);

/* ---- Color quantization (used by avscolor) -------------- */
/* Map a 0xRRGGBB value to the closest xterm-16 index (0..15). */
TVCAPI uint8_t  TVCALL TvColor_RGBtoXTerm16(uint32_t rgb);
/* Map a 0xRRGGBB value to an xterm-256 index in [16..255].   */
TVCAPI uint8_t  TVCALL TvColor_RGBtoXTerm256(uint32_t rgb);
/* Reverse the xterm-256 index 16..255 back to 0xRRGGBB.      */
TVCAPI uint32_t TVCALL TvColor_XTerm256toRGB(uint8_t index);

/* ---- Misc ----------------------------------------------- */
TVCAPI const char* TVCALL TvVersion(void);

#ifdef __cplusplus
}
#endif

#endif /* TVISION_C_H */
