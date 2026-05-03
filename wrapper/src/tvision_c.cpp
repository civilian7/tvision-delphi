// ============================================================
//  tvision_c.cpp
//  Implementation of the C ABI wrapper for tvision.
// ============================================================

#define Uses_TKeys
#define Uses_TApplication
#define Uses_TProgram
#define Uses_TEvent
#define Uses_TRect
#define Uses_TView
#define Uses_TGroup
#define Uses_TWindow
#define Uses_TDialog
#define Uses_TStaticText
#define Uses_TButton
#define Uses_TLabel
#define Uses_TInputLine
#define Uses_TCheckBoxes
#define Uses_TRadioButtons
#define Uses_TSItem
#define Uses_TMenuBar
#define Uses_TSubMenu
#define Uses_TMenuItem
#define Uses_TStatusLine
#define Uses_TStatusItem
#define Uses_TStatusDef
#define Uses_TDeskTop
#define Uses_MsgBox
#define Uses_TFileDialog
#define Uses_TFileInputLine
#define Uses_TScrollBar
#define Uses_TParamText
#define Uses_TEditWindow
#define Uses_TFileEditor
#define Uses_TEditor
#define Uses_TPalette
#define Uses_TDrawBuffer
#include <tvision/tv.h>
#include <tvision/stddlg.h>
#include <tvision/colors.h>

#define TVCAPI_BUILD
#include "tvision_c.h"

#include <cstring>
#include <vector>
#include <string>

// ---------- Helpers ------------------------------------------------
static inline TRect toRect(const TvRect& r) {
    return TRect(r.ax, r.ay, r.bx, r.by);
}
static inline TRect toRect(const TvRect* r) {
    return TRect(r->ax, r->ay, r->bx, r->by);
}

// ---------- Custom view subclass ----------------------------------
class TWrapView : public TView {
public:
    TvDrawCallback      drawCb_  = nullptr;
    TvViewEventCallback eventCb_ = nullptr;
    void*               userData = nullptr;
    bool                hasPalette = false;
    std::string         paletteBytes;

    TWrapView(const TRect& r,
              TvDrawCallback d, TvViewEventCallback e,
              const char* pal, int palLen, void* ud)
        : TView(r), drawCb_(d), eventCb_(e), userData(ud)
    {
        options |= ofSelectable;
        eventMask = evMouseDown | evKeyDown | evCommand | evBroadcast;
        if (pal && palLen > 0) {
            paletteBytes.assign(pal, palLen);
            hasPalette = true;
        }
    }

    void draw() override {
        if (drawCb_) drawCb_(this, userData);
        else TView::draw();
    }

    TPalette& getPalette() const override {
        if (hasPalette) {
            static thread_local TPalette p("", 0);
            p = TPalette(paletteBytes.data(), (ushort)paletteBytes.size());
            return p;
        }
        return TView::getPalette();
    }

    void handleEvent(TEvent& event) override {
        TView::handleEvent(event);
        if (eventCb_) {
            TvEvent ev{};
            ev.what = event.what;
            if (event.what & evCommand) {
                ev.command = event.message.command;
                ev.infoPtr = event.message.infoPtr;
            } else if (event.what & evKeyboard) {
                ev.command = event.keyDown.keyCode;
            }
            if (eventCb_(this, &ev, userData)) clearEvent(event);
        }
    }

    // Public access to protected drawing primitives:
    void publicWriteStr(short x, short y, const char* s, uchar c) {
        writeStr(x, y, s, c);
    }
    void publicWriteChar(short x, short y, char c, uchar color, short count) {
        writeChar(x, y, c, color, count);
    }
};

// ---------- Custom application ------------------------------------
namespace {

struct AppCallbacks {
    TvMenuBuilder    menu = nullptr;
    TvStatusBuilder  status = nullptr;
    TvEventHandler   event = nullptr;
    TvIdleHandler    idle = nullptr;
    void*            data = nullptr;
};

// Global pointer used while constructing a TApplication. We
// need this because TApplication's ctor calls the static
// init* functions before the object exists, so they cannot
// access instance fields.
thread_local AppCallbacks* g_currentCallbacks = nullptr;

class TWrapApp : public TApplication {
public:
    AppCallbacks cb;

    TWrapApp(const AppCallbacks& c)
        : TProgInit(&TWrapApp::initStatusLineCB,
                    &TWrapApp::initMenuBarCB,
                    &TWrapApp::initDeskTop)
    {
        cb = c;
    }

    static TMenuBar* initMenuBarCB(TRect r) {
        if (g_currentCallbacks && g_currentCallbacks->menu) {
            TvRect tr{ (int16_t)r.a.x, (int16_t)r.a.y,
                       (int16_t)r.b.x, (int16_t)r.b.y };
            tr.by = tr.ay + 1;
            return (TMenuBar*)g_currentCallbacks->menu(&tr,
                       g_currentCallbacks->data);
        }
        // default: empty menu bar
        r.b.y = r.a.y + 1;
        return new TMenuBar(r, (TMenu*)nullptr);
    }

    static TStatusLine* initStatusLineCB(TRect r) {
        if (g_currentCallbacks && g_currentCallbacks->status) {
            TvRect tr{ (int16_t)r.a.x, (int16_t)r.a.y,
                       (int16_t)r.b.x, (int16_t)r.b.y };
            tr.ay = tr.by - 1;
            return (TStatusLine*)g_currentCallbacks->status(&tr,
                       g_currentCallbacks->data);
        }
        r.a.y = r.b.y - 1;
        return new TStatusLine(r,
            *new TStatusDef(0, 0xFFFF,
                new TStatusItem("~Alt-X~ Exit", kbAltX, cmQuit)));
    }

    void handleEvent(TEvent& event) override {
        TApplication::handleEvent(event);
        if (cb.event) {
            TvEvent ev{};
            ev.what    = event.what;
            if (event.what & evCommand) {
                ev.command = event.message.command;
                ev.infoInt = (int32_t)(intptr_t)event.message.infoPtr;
                ev.infoPtr = event.message.infoPtr;
            } else if (event.what & evKeyboard) {
                ev.command = event.keyDown.keyCode;
            }
            int handled = cb.event(&ev, cb.data);
            if (handled) {
                clearEvent(event);
            }
        }
    }

    void idle() override {
        TApplication::idle();
        if (cb.idle) cb.idle(cb.data);
    }
};

// ---------- Menu builder state ------------------------------------
struct MenuBuildState {
    TRect      barRect;
    TSubMenu*  firstSub = nullptr;    // first submenu at bar level
    TSubMenu*  curSub   = nullptr;    // current open submenu
};

thread_local MenuBuildState g_menuState;

// ---------- Status line state -------------------------------------
struct StatusBuildState {
    TRect       rect;
    TStatusItem* head = nullptr;
};
thread_local StatusBuildState g_statusState;

} // namespace

// ============================================================
//  Public C API
// ============================================================
extern "C" {

TVCAPI const char* TVCALL TvVersion(void) {
    return "tvision_c 0.1";
}

// ----- Color quantization (used by avscolor) -----
static inline TColorRGB rgbFromU32(uint32_t v) {
    TColorRGB c;
    c.r = (uint8_t)(v >> 16);
    c.g = (uint8_t)(v >> 8);
    c.b = (uint8_t)(v);
    return c;
}

TVCAPI uint8_t TVCALL TvColor_RGBtoXTerm16(uint32_t rgb) {
    return ::RGBtoXTerm16(rgbFromU32(rgb));
}
TVCAPI uint8_t TVCALL TvColor_RGBtoXTerm256(uint32_t rgb) {
    return ::RGBtoXTerm256(rgbFromU32(rgb));
}
TVCAPI uint32_t TVCALL TvColor_XTerm256toRGB(uint8_t idx) {
    TColorRGB c = ::XTerm256toRGB(idx);
    return ((uint32_t)c.r << 16) | ((uint32_t)c.g << 8) | (uint32_t)c.b;
}

// ----- Application -----
TVCAPI TvAppHandle TVCALL TvApp_Create(
    TvMenuBuilder menu,
    TvStatusBuilder status,
    TvEventHandler event,
    TvIdleHandler idle,
    void* appData)
{
    AppCallbacks cb;
    cb.menu = menu;
    cb.status = status;
    cb.event = event;
    cb.idle = idle;
    cb.data = appData;

    g_currentCallbacks = &cb;
    TWrapApp* app = new TWrapApp(cb);
    g_currentCallbacks = nullptr;
    return (TvAppHandle)app;
}

TVCAPI void TVCALL TvApp_Run(TvAppHandle app) {
    if (app) ((TWrapApp*)app)->run();
}

TVCAPI void TVCALL TvApp_Suspend(TvAppHandle app) {
    if (app) ((TWrapApp*)app)->suspend();
}

TVCAPI void TVCALL TvApp_Resume(TvAppHandle app) {
    if (app) ((TWrapApp*)app)->resume();
}

TVCAPI void TVCALL TvApp_Destroy(TvAppHandle app) {
    if (app) {
        TWrapApp* a = (TWrapApp*)app;
        TObject::destroy(a);
    }
}

TVCAPI TvViewHandle TVCALL TvApp_GetDeskTop(TvAppHandle app) {
    (void)app;
    return (TvViewHandle)TProgram::deskTop;
}

TVCAPI void TVCALL TvApp_GetExtent(TvAppHandle app, TvRect* outRect) {
    (void)app;
    if (!outRect) return;
    TRect r = TProgram::deskTop->getExtent();
    outRect->ax = (int16_t)r.a.x;
    outRect->ay = (int16_t)r.a.y;
    outRect->bx = (int16_t)r.b.x;
    outRect->by = (int16_t)r.b.y;
}

TVCAPI void TVCALL TvApp_InsertWindow(TvAppHandle app, TvWindowHandle win) {
    (void)app;
    if (win) TProgram::deskTop->insert((TView*)win);
}

TVCAPI uint16_t TVCALL TvApp_ExecView(TvAppHandle app, TvViewHandle view) {
    (void)app;
    if (!view) return 0;
    return (uint16_t)TProgram::deskTop->execView((TView*)view);
}

TVCAPI void TVCALL TvView_Destroy(TvViewHandle view) {
    if (!view) return;
    TView* tv = (TView*)view;
    // If the view is still in a parent group, remove it first so
    // the parent invalidates the screen area before deletion.
    // Without this the desktop keeps a dangling pointer and the
    // area underneath is never repainted, leaving frame artifacts.
    if (tv->owner) {
        tv->owner->remove(tv);
    }
    TObject::destroy(tv);
}

TVCAPI void TVCALL TvView_Redraw(TvViewHandle view) {
    if (view) ((TView*)view)->drawView();
}

TVCAPI void TVCALL TvApp_Redraw(TvAppHandle app) {
    (void)app;
    if (TProgram::application) TProgram::application->redraw();
}

// ----- Menu builder -----
TVCAPI void TVCALL TvMenu_BeginBar(const TvRect* r) {
    g_menuState = MenuBuildState{};
    g_menuState.barRect = toRect(r);
    g_menuState.barRect.b.y = g_menuState.barRect.a.y + 1;
}

TVCAPI void TVCALL TvMenu_AddSub(const char* title, uint16_t hotKey) {
    TSubMenu* sub = new TSubMenu(title ? title : "", hotKey);
    if (!g_menuState.firstSub) {
        g_menuState.firstSub = sub;
    } else {
        // Chain submenus at bar level via overloaded operator+
        (void)(*g_menuState.firstSub + *sub);
    }
    g_menuState.curSub = sub;
}

TVCAPI void TVCALL TvMenu_EndSub(void) {
    g_menuState.curSub = nullptr;
}

TVCAPI void TVCALL TvMenu_AddItem(const char* title,
                                  uint16_t command,
                                  uint16_t keyCode,
                                  const char* hint)
{
    if (!g_menuState.curSub) return;
    TMenuItem* item = new TMenuItem(
        title ? title : "",
        command,
        keyCode,
        hcNoContext,
        hint ? hint : nullptr,
        (TMenuItem*)nullptr);
    (void)(*g_menuState.curSub + *item);
}

TVCAPI void TVCALL TvMenu_AddLine(void) {
    if (!g_menuState.curSub) return;
    (void)(*g_menuState.curSub + newLine());
}

TVCAPI TvMenuHandle TVCALL TvMenu_FinishBar(void) {
    TMenuBar* bar;
    if (g_menuState.firstSub) {
        bar = new TMenuBar(g_menuState.barRect, *g_menuState.firstSub);
    } else {
        bar = new TMenuBar(g_menuState.barRect, (TMenu*)nullptr);
    }
    g_menuState = MenuBuildState{};
    return (TvMenuHandle)bar;
}

// ----- Status line builder -----
TVCAPI void TVCALL TvStatus_Begin(const TvRect* r) {
    g_statusState = StatusBuildState{};
    g_statusState.rect = toRect(r);
    g_statusState.rect.a.y = g_statusState.rect.b.y - 1;
}

TVCAPI void TVCALL TvStatus_AddItem(const char* text,
                                    uint16_t keyCode,
                                    uint16_t command)
{
    TStatusItem* item = new TStatusItem(
        (text && *text) ? text : nullptr,
        keyCode,
        command);
    if (!g_statusState.head) {
        g_statusState.head = item;
    } else {
        TStatusItem* p = g_statusState.head;
        while (p->next) p = p->next;
        p->next = item;
    }
}

TVCAPI TvStatusHandle TVCALL TvStatus_Finish(void) {
    TStatusDef* def = new TStatusDef(0, 0xFFFF, g_statusState.head);
    TStatusLine* line = new TStatusLine(g_statusState.rect, *def);
    g_statusState = StatusBuildState{};
    return (TvStatusHandle)line;
}

// ----- Dialogs / Windows -----
TVCAPI TvDialogHandle TVCALL TvDialog_Create(const TvRect* r, const char* title) {
    return (TvDialogHandle)new TDialog(toRect(r), title ? title : "");
}

TVCAPI TvWindowHandle TVCALL TvWindow_Create(const TvRect* r, const char* title,
                                             int16_t windowNumber) {
    return (TvWindowHandle)new TWindow(toRect(r), title ? title : "", windowNumber);
}

TVCAPI void TVCALL TvView_Insert(TvViewHandle parent, TvViewHandle child) {
    if (parent && child) ((TGroup*)parent)->insert((TView*)child);
}

TVCAPI void TVCALL TvView_SetData(TvViewHandle view, const void* data) {
    if (view) ((TView*)view)->setData((void*)data);
}

TVCAPI void TVCALL TvView_GetData(TvViewHandle view, void* data) {
    if (view) ((TView*)view)->getData(data);
}

// ----- Widgets -----
TVCAPI TvViewHandle TVCALL TvStaticText_Create(const TvRect* r, const char* text) {
    return (TvViewHandle)new TStaticText(toRect(r), text ? text : "");
}

TVCAPI TvViewHandle TVCALL TvButton_Create(const TvRect* r,
                                           const char* title,
                                           uint16_t command,
                                           uint16_t flags)
{
    return (TvViewHandle)new TButton(toRect(r),
                                     title ? title : "",
                                     command,
                                     (ushort)flags);
}

TVCAPI TvViewHandle TVCALL TvLabel_Create(const TvRect* r,
                                          const char* text,
                                          TvViewHandle linkedView)
{
    return (TvViewHandle)new TLabel(toRect(r),
                                    text ? text : "",
                                    (TView*)linkedView);
}

TVCAPI TvViewHandle TVCALL TvInputLine_Create(const TvRect* r, int16_t maxLen) {
    return (TvViewHandle)new TInputLine(toRect(r), maxLen);
}

static TSItem* buildSItemChain(const char* const* items, int count) {
    TSItem* head = nullptr;
    for (int i = count - 1; i >= 0; --i) {
        head = new TSItem(items[i] ? items[i] : "", head);
    }
    return head;
}

TVCAPI TvViewHandle TVCALL TvCheckBoxes_Create(const TvRect* r,
                                               const char* const* items,
                                               int count)
{
    TSItem* chain = buildSItemChain(items, count);
    return (TvViewHandle)new TCheckBoxes(toRect(r), chain);
}

TVCAPI TvViewHandle TVCALL TvRadioButtons_Create(const TvRect* r,
                                                 const char* const* items,
                                                 int count)
{
    TSItem* chain = buildSItemChain(items, count);
    return (TvViewHandle)new TRadioButtons(toRect(r), chain);
}

// ----- Message / input boxes -----
TVCAPI uint16_t TVCALL TvMessageBox(const char* msg, uint16_t options) {
    return (uint16_t)messageBox(msg ? msg : "", options);
}

// ----- Editor (TEditWindow) -----
TVCAPI TvWindowHandle TVCALL TvEditWindow_Create(const TvRect* r,
                                                 const char* fileName,
                                                 int16_t windowNumber)
{
    short num = (windowNumber < 0) ? wnNoNumber : windowNumber;
    TStringView fn = (fileName && *fileName) ? TStringView(fileName)
                                             : TStringView();
    return (TvWindowHandle)new TEditWindow(toRect(r), fn, num);
}

// ----- Custom view -----
TVCAPI TvViewHandle TVCALL TvCustomView_Create(
    const TvRect*       r,
    TvDrawCallback      drawCb,
    TvViewEventCallback eventCb,
    const char*         paletteBytes,
    int                 paletteLen,
    void*               userData)
{
    return (TvViewHandle)new TWrapView(toRect(r),
                                       drawCb, eventCb,
                                       paletteBytes, paletteLen, userData);
}

// ----- View drawing primitives -----
TVCAPI void TVCALL TvView_GetSize(TvViewHandle v, int* outCx, int* outCy) {
    if (!v) return;
    TView* tv = (TView*)v;
    if (outCx) *outCx = tv->size.x;
    if (outCy) *outCy = tv->size.y;
}

TVCAPI uint8_t TVCALL TvView_GetColor(TvViewHandle v, uint16_t paletteIndex) {
    if (!v) return 0;
    TAttrPair pair = ((TView*)v)->getColor(paletteIndex);
    // pair[0] is the resolved attribute for the index
    TColorAttr ca = pair[0];
    // Pack to 8-bit "DOS attribute" form (fg lo nibble, bg hi nibble).
    auto fg = (uint8_t)::getFore(ca).asBIOS();
    auto bg = (uint8_t)::getBack(ca).asBIOS();
    return (uint8_t)((bg << 4) | (fg & 0x0F));
}

TVCAPI void TVCALL TvView_WriteText(TvViewHandle v, int x, int y,
                                    const char* text, uint8_t attr)
{
    if (!v || !text) return;
    ((TWrapView*)v)->publicWriteStr((short)x, (short)y, text, (uchar)attr);
}

TVCAPI void TVCALL TvView_WriteFill(TvViewHandle v, int x, int y,
                                    int w, int h, char ch, uint8_t attr)
{
    if (!v) return;
    TWrapView* wv = (TWrapView*)v;
    for (int row = 0; row < h; ++row) {
        wv->publicWriteChar((short)x, (short)(y + row), ch, (uchar)attr, (short)w);
    }
}

TVCAPI void TVCALL TvView_SetOptionCentered(TvViewHandle v) {
    if (v) ((TView*)v)->options |= ofCentered;
}

// ----- Command enable / disable -----
TVCAPI void TVCALL TvApp_EnableCommand(uint16_t command) {
    TView::enableCommand(command);
}
TVCAPI void TVCALL TvApp_DisableCommand(uint16_t command) {
    TView::disableCommand(command);
}

// ----- File dialog -----
TVCAPI TvDialogHandle TVCALL TvFileDialog_Create(
    const char* wildCard,
    const char* title,
    const char* inputName,
    uint16_t    options,
    uint8_t     histId)
{
    return (TvDialogHandle)new TFileDialog(
        wildCard ? wildCard : "*.*",
        title ? title : "Open",
        inputName ? inputName : "~N~ame",
        (ushort)options,
        histId);
}

TVCAPI int TVCALL TvFileDialog_GetFileName(TvDialogHandle dlg,
                                           char* buffer, int bufferSize)
{
    if (!dlg || !buffer || bufferSize <= 0) return 0;
    char tmp[260] = {0};
    ((TFileDialog*)dlg)->getFileName(tmp);
    int n = (int)std::strlen(tmp);
    if (n >= bufferSize) n = bufferSize - 1;
    std::memcpy(buffer, tmp, n);
    buffer[n] = 0;
    return n;
}

// ----- Window management -----
TVCAPI void TVCALL TvApp_SetMenuBar(TvAppHandle app, TvMenuHandle newMenu) {
    (void)app;
    if (!newMenu) return;
    TMenuBar* old = TProgram::menuBar;
    TMenuBar* nb  = (TMenuBar*)newMenu;
    if (old) {
        TProgram::application->remove(old);
        TObject::destroy(old);
    }
    TProgram::menuBar = nb;
    TProgram::application->insert(nb);
}

TVCAPI void TVCALL TvApp_DesktopTile(TvAppHandle app) {
    (void)app;
    TProgram::deskTop->tile(TProgram::deskTop->getExtent());
}

TVCAPI void TVCALL TvApp_DesktopCascade(TvAppHandle app) {
    (void)app;
    TProgram::deskTop->cascade(TProgram::deskTop->getExtent());
}

TVCAPI void TVCALL TvApp_BroadcastCmd(TvAppHandle app, uint16_t command) {
    (void)app;
    message(TProgram::deskTop, evBroadcast, command, nullptr);
}

static void countView(TView* p, void* data) {
    (void)p;
    (*(int*)data)++;
}

TVCAPI int TVCALL TvApp_DesktopWindowCount(TvAppHandle app) {
    (void)app;
    int n = 0;
    TProgram::deskTop->forEach(&countView, &n);
    // Subtract 1 for the background view that the desktop owns
    return n > 0 ? n - 1 : 0;
}

TVCAPI uint16_t TVCALL TvInputBox(const char* title,
                                  const char* label,
                                  char* buffer,
                                  int bufferSize)
{
    if (!buffer || bufferSize <= 0) return 0;
    return (uint16_t)inputBox(
        title ? title : "",
        label ? label : "",
        buffer,
        (uchar)((bufferSize > 255) ? 255 : bufferSize));
}

} // extern "C"
