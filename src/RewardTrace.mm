#include "RewardTraceOffsets.h"
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <syslog.h>
#include <atomic>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstring>

namespace rt {
using MSHookFunctionFn = void (*)(void *, void *, void **);
using Il2CppStringLengthFn = std::int32_t (*)(void *);
using Il2CppStringCharsFn = const std::uint16_t *(*)(void *);
static std::atomic<bool> gInstalled{false};
static std::atomic<int> gBusiness{0};
static MSHookFunctionFn gMSHookFunction = nullptr;
static Il2CppStringLengthFn gStringLength = nullptr;
static Il2CppStringCharsFn gStringChars = nullptr;
static std::intptr_t gSlide = 0;
static std::uint64_t gTextVMAddr = 0;
static std::uint64_t gTextVMSize = 0;

static void Log(const char *fmt, ...) {
    char body[1536] = {};
    va_list ap;
    va_start(ap, fmt);
    std::vsnprintf(body, sizeof(body), fmt, ap);
    va_end(ap);
    char line[1664] = {};
    std::snprintf(line, sizeof(line), "[RewardTrace] %s", body);
    std::fprintf(stderr, "%s\n", line);
    std::fflush(stderr);
    syslog(LOG_NOTICE, "%s", line);
}
static const char *BusinessName(int id) {
    switch (id) {
        case 1: return "coop_tickets";
        case 2: return "daily_free_pack";
        case 3: return "chuseok_free";
        case 4: return "coop_boost";
        default: return "unknown";
    }
}
template <typename T> static T ReadField(const void *base, std::size_t offset) {
    T value{};
    if (base) std::memcpy(&value, static_cast<const std::uint8_t *>(base) + offset, sizeof(T));
    return value;
}
static void UTF16ToUTF8(const std::uint16_t *input, std::int32_t length, char *out, std::size_t outSize) {
    if (!out || outSize == 0) return;
    out[0] = '\0';
    if (!input || length <= 0) return;
    std::size_t o = 0;
    const std::int32_t maxUnits = length > 240 ? 240 : length;
    for (std::int32_t i = 0; i < maxUnits && o + 4 < outSize; ++i) {
        std::uint32_t cp = input[i];
        if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < maxUnits) {
            const std::uint32_t lo = input[i + 1];
            if (lo >= 0xDC00 && lo <= 0xDFFF) { cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00); ++i; }
        }
        if (cp <= 0x7F) out[o++] = static_cast<char>(cp);
        else if (cp <= 0x7FF) { out[o++] = static_cast<char>(0xC0 | (cp >> 6)); out[o++] = static_cast<char>(0x80 | (cp & 0x3F)); }
        else if (cp <= 0xFFFF) { out[o++] = static_cast<char>(0xE0 | (cp >> 12)); out[o++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F)); out[o++] = static_cast<char>(0x80 | (cp & 0x3F)); }
        else { out[o++] = static_cast<char>(0xF0 | (cp >> 18)); out[o++] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F)); out[o++] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F)); out[o++] = static_cast<char>(0x80 | (cp & 0x3F)); }
    }
    out[o] = '\0';
}
static const char *ManagedString(void *str, char *buf, std::size_t bufSize) {
    if (!str) return "<null>";
    if (!gStringLength || !gStringChars) { std::snprintf(buf, bufSize, "<Il2CppString@%p>", str); return buf; }
    const auto len = gStringLength(str);
    const auto chars = gStringChars(str);
    if (len < 0 || len > 4096 || !chars) { std::snprintf(buf, bufSize, "<invalid-Il2CppString@%p len=%d>", str, len); return buf; }
    UTF16ToUTF8(chars, len, buf, bufSize);
    return buf;
}
static void LogGameResponse(const char *label, void *res) {
    if (!res) { Log("%s response=<null>", label); return; }
    Log("%s response=%p errorCode=%d serverResult=%d", label, res,
        ReadField<std::int32_t>(res, 0x10), ReadField<std::int32_t>(res, 0x14));
}
static void LogRewardResponse(const char *label, void *res) {
    LogGameResponse(label, res);
    if (!res) return;
    Log("%s rewardList=%p updateGoodsDict=%p", label, ReadField<void *>(res, 0x28), ReadField<void *>(res, 0x30));
}
static bool UUIDMatches(const mach_header_64 *header, char *uuidText, std::size_t uuidTextSize) {
    const auto *cursor = reinterpret_cast<const std::uint8_t *>(header) + sizeof(mach_header_64);
    const uuid_command *uuidCmd = nullptr;
    gTextVMAddr = gTextVMSize = 0;
    for (std::uint32_t i = 0; i < header->ncmds; ++i) {
        const auto *lc = reinterpret_cast<const load_command *>(cursor);
        if (lc->cmdsize < sizeof(load_command)) return false;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(uuid_command)) uuidCmd = reinterpret_cast<const uuid_command *>(cursor);
        else if (lc->cmd == LC_SEGMENT_64 && lc->cmdsize >= sizeof(segment_command_64)) {
            const auto *seg = reinterpret_cast<const segment_command_64 *>(cursor);
            if (std::strncmp(seg->segname, "__TEXT", sizeof(seg->segname)) == 0) { gTextVMAddr = seg->vmaddr; gTextVMSize = seg->vmsize; }
        }
        cursor += lc->cmdsize;
    }
    if (!uuidCmd) return false;
    const auto *u = uuidCmd->uuid;
    std::snprintf(uuidText, uuidTextSize, "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                  u[0],u[1],u[2],u[3],u[4],u[5],u[6],u[7],u[8],u[9],u[10],u[11],u[12],u[13],u[14],u[15]);
    return std::strcmp(uuidText, rewardtrace::kExpectedUnityFrameworkUUID) == 0;
}
static void *Address(std::uint64_t va) { return reinterpret_cast<void *>(static_cast<std::uintptr_t>(gSlide) + va); }
static bool AddressInText(std::uint64_t va) { return gTextVMSize && va >= gTextVMAddr && va < gTextVMAddr + gTextVMSize; }
static bool InstallHook(std::uint64_t rva, const char *name, void *replacement, void **original) {
    if (!AddressInText(rva)) { Log("REFUSE hook %s RVA=0x%llX outside __TEXT", name, static_cast<unsigned long long>(rva)); return false; }
    void *target = Address(rva);
    *original = nullptr;
    gMSHookFunction(target, replacement, original);
    Log("hook %-38s RVA=0x%llX runtime=%p original=%p", name, static_cast<unsigned long long>(rva), target, *original);
    return *original != nullptr;
}

using VoidSelf = void (*)(void *, const void *);
using VoidSelfBool = void (*)(void *, bool, const void *);
using VoidSelfObj = void (*)(void *, void *, const void *);
using VoidSelfObjObj = void (*)(void *, void *, void *, const void *);
using BoolSelfInt = bool (*)(void *, std::int32_t, const void *);
using BoolSelfObj = bool (*)(void *, void *, const void *);
using VoidSelfObjBool = void (*)(void *, void *, bool, const void *);
using VoidSelfInt3 = void (*)(void *, std::int32_t, std::int32_t, std::int32_t, const void *);
using VoidStaticString3 = void (*)(void *, void *, void *, const void *);

static VoidSelf oCoopTicketsClick, oDailyFreePackClick, oChuseokClick, oCoopBoostClick;
static void hCoopTicketsClick(void *s,const void *m){ gBusiness=1; Log("[coop_tickets] CLICK self=%p",s); oCoopTicketsClick(s,m); }
static void hDailyFreePackClick(void *s,const void *m){ gBusiness=2; Log("[daily_free_pack] CLICK self=%p",s); oDailyFreePackClick(s,m); }
static void hChuseokClick(void *s,const void *m){ gBusiness=3; Log("[chuseok_free] CLICK self=%p",s); oChuseokClick(s,m); }
static void hCoopBoostClick(void *s,const void *m){ gBusiness=4; Log("[coop_boost] CLICK self=%p",s); oCoopBoostClick(s,m); }

static VoidSelf oAdsPlayMoveNext;
static void hAdsPlayMoveNext(void *s,const void *m){
    char b[512]{}; const auto state=ReadField<std::int32_t>(s,0); void *placement=ReadField<void *>(s,0x18);
    Log("[%s] AdsController.PlayAds_RewardVideo.MoveNext state=%d placement=%s",BusinessName(gBusiness.load()),state,ManagedString(placement,b,sizeof(b)));
    oAdsPlayMoveNext(s,m);
}
static VoidSelfBool oAdsCompletion;
static void hAdsCompletion(void *s,bool result,const void *m){ Log("[%s] AdsController.<ShowRewardVideo>b__0 result=%d",BusinessName(gBusiness.load()),result?1:0); oAdsCompletion(s,result,m); }
static VoidSelfObjObj oMaxShowReward;
static void hMaxShowReward(void *s,void *p,void *cb,const void *m){ Log("[%s] MaxMediation.ShowRewardVideo self=%p adEventParams=%p callback=%p",BusinessName(gBusiness.load()),s,p,cb); oMaxShowReward(s,p,cb,m); }
static VoidStaticString3 oMaxSdkShowRewardedAd;
static void hMaxSdkShowRewardedAd(void *unit,void *placement,void *custom,const void *m){ char a[256]{},p[256]{},c[256]{}; Log("[%s] MaxSdkiOS.ShowRewardedAd adUnit=%s placement=%s customData=%s",BusinessName(gBusiness.load()),ManagedString(unit,a,sizeof(a)),ManagedString(placement,p,sizeof(p)),ManagedString(custom,c,sizeof(c))); oMaxSdkShowRewardedAd(unit,placement,custom,m); }
static VoidSelfObjObj oMaxReceivedReward;
static void hMaxReceivedReward(void *s,void *eh,void *args,const void *m){ Log("[%s] MAX ReceivedReward ENTER hasReceivedReward=%d",BusinessName(gBusiness.load()),ReadField<std::uint8_t>(s,0x38)?1:0); oMaxReceivedReward(s,eh,args,m); Log("[%s] MAX ReceivedReward EXIT hasReceivedReward=%d",BusinessName(gBusiness.load()),ReadField<std::uint8_t>(s,0x38)?1:0); }
static VoidSelfObjObj oMaxHidden;
static void hMaxHidden(void *s,void *eh,void *args,const void *m){ Log("[%s] MAX Hidden ENTER hasReceivedReward=%d",BusinessName(gBusiness.load()),ReadField<std::uint8_t>(s,0x38)?1:0); oMaxHidden(s,eh,args,m); Log("[%s] MAX Hidden EXIT",BusinessName(gBusiness.load())); }

#define DEF_BOOL_CB(N,TAG) static VoidSelfBool o##N; static void h##N(void*s,bool v,const void*m){ Log("[" TAG "] BUSINESS callback success=%d",v?1:0); o##N(s,v,m); }
DEF_BOOL_CB(CoopTicketsAdResult,"coop_tickets")
DEF_BOOL_CB(DailyFreePackAdResult,"daily_free_pack")
DEF_BOOL_CB(ChuseokAdResult,"chuseok_free")
DEF_BOOL_CB(CoopBoostAdResult,"coop_boost")

static VoidSelf oRpcCoopTickets;
static void hRpcCoopTickets(void*s,const void*m){ Log("[coop_tickets] RPC MoveNext state=%d",ReadField<std::int32_t>(s,0)); oRpcCoopTickets(s,m); }
static VoidSelf oRpcDailyFree;
static void hRpcDailyFree(void*s,const void*m){ Log("[daily_free_pack] RPC MoveNext state=%d id=%d",ReadField<std::int32_t>(s,0),ReadField<std::int32_t>(s,0x20)); oRpcDailyFree(s,m); }
static VoidSelf oRpcChuseok;
static void hRpcChuseok(void*s,const void*m){ Log("[chuseok_free] RPC MoveNext state=%d freeId=%d",ReadField<std::int32_t>(s,0),ReadField<std::int32_t>(s,0x20)); oRpcChuseok(s,m); }
static VoidSelf oRpcCoopBoost;
static void hRpcCoopBoost(void*s,const void*m){ Log("[coop_boost] RPC MoveNext state=%d",ReadField<std::int32_t>(s,0)); oRpcCoopBoost(s,m); }

static VoidSelfObj oCoopTicketsSuccess;
static void hCoopTicketsSuccess(void*s,void*r,const void*m){ LogRewardResponse("[coop_tickets] SUCCESS",r); if(r) Log("[coop_tickets] dailyAdsCoopTickets=%d",ReadField<std::int32_t>(r,0x40)); oCoopTicketsSuccess(s,r,m); }
static VoidSelfObj oDailyFreePackSuccess;
static void hDailyFreePackSuccess(void*s,void*r,const void*m){ LogRewardResponse("[daily_free_pack] SUCCESS",r); if(r) Log("[daily_free_pack] dailyFreePackageInfo=%p",ReadField<void*>(r,0x40)); oDailyFreePackSuccess(s,r,m); }
static VoidSelfObj oChuseokSuccess1,oChuseokSuccess2;
static void LogChuseok(const char*w,void*r){ LogRewardResponse(w,r); if(r) Log("%s freeId=%d receiveCount=%d receiveDay=%d",w,ReadField<std::int32_t>(r,0x40),ReadField<std::int32_t>(r,0x44),ReadField<std::int32_t>(r,0x48)); }
static void hChuseokSuccess1(void*s,void*r,const void*m){ LogChuseok("[chuseok_free] SUCCESS b__2",r); oChuseokSuccess1(s,r,m); }
static void hChuseokSuccess2(void*s,void*r,const void*m){ LogChuseok("[chuseok_free] SUCCESS b__0",r); oChuseokSuccess2(s,r,m); }
static VoidSelfObj oCoopBoostSuccess;
static void hCoopBoostSuccess(void*s,void*r,const void*m){ LogGameResponse("[coop_boost] SUCCESS",r); if(r) Log("[coop_boost] watchCount=%d remainCount=%d",ReadField<std::int32_t>(r,0x20),ReadField<std::int32_t>(r,0x24)); oCoopBoostSuccess(s,r,m); }

static BoolSelfInt oHandleError;
static bool hHandleError(void*s,std::int32_t code,const void*m){ const bool r=oHandleError(s,code,m); Log("[server] HandleError code=%d -> %d",code,r?1:0); return r; }
static BoolSelfObj oHandleServerResult;
static bool hHandleServerResult(void*s,void*response,const void*m){ LogGameResponse("[server] HandleServerResult ENTER",response); const bool r=oHandleServerResult(s,response,m); Log("[server] HandleServerResult EXIT -> %d",r?1:0); return r; }
static VoidSelfObjBool oHandleSuccessedResponse;
static void hHandleSuccessedResponse(void*s,void*response,bool show,const void*m){ LogGameResponse("[server] HandleSuccessedResponse",response); Log("[server] showRewardPopup=%d",show?1:0); oHandleSuccessedResponse(s,response,show,m); }
static VoidSelfInt3 oSetChuseokReceiveCount;
static void hSetChuseokReceiveCount(void*s,std::int32_t freeId,std::int32_t count,std::int32_t day,const void*m){ Log("[chuseok_free] DataManager.SetChuseokShopFreeReceiveCount freeId=%d count=%d day=%d",freeId,count,day); oSetChuseokReceiveCount(s,freeId,count,day,m); }
static VoidSelf oRefreshCoopTicketUI;
static void hRefreshCoopTicketUI(void*s,const void*m){ Log("[coop_boost] MenuBattle.RefreshCoopTicketUI"); oRefreshCoopTicketUI(s,m); }

static bool InstallAllHooks(){
    bool ok=true;
#define H(R,N,F,O) do{ ok=InstallHook((R),(N),reinterpret_cast<void*>(F),reinterpret_cast<void**>(&(O)))&&ok; }while(0)
    H(rewardtrace::kCoopTicketsClick,"PopupCoopTicketsBuy.ClickAdsCoopTickets",hCoopTicketsClick,oCoopTicketsClick);
    H(rewardtrace::kDailyFreePackClick,"FreePackButton.Click",hDailyFreePackClick,oDailyFreePackClick);
    H(rewardtrace::kChuseokFreeClick,"ChuseokShopFreeButton.Click",hChuseokClick,oChuseokClick);
    H(rewardtrace::kCoopBoostClick,"MenuBattle.ClickCoopAdWatch",hCoopBoostClick,oCoopBoostClick);
    H(rewardtrace::kAdsPlayRewardMoveNext,"AdsController.PlayAds_RewardVideo.MoveNext",hAdsPlayMoveNext,oAdsPlayMoveNext);
    H(rewardtrace::kAdsShowCompletionCallback,"AdsController.ShowRewardVideo completion",hAdsCompletion,oAdsCompletion);
    H(rewardtrace::kMaxMediationShowRewardVideo,"MaxMediation.ShowRewardVideo",hMaxShowReward,oMaxShowReward);
    H(rewardtrace::kMaxSdkShowRewardedAd,"MaxSdkiOS.ShowRewardedAd",hMaxSdkShowRewardedAd,oMaxSdkShowRewardedAd);
    H(rewardtrace::kMaxReceivedRewardCallback,"MAX ReceivedReward callback",hMaxReceivedReward,oMaxReceivedReward);
    H(rewardtrace::kMaxHiddenCallback,"MAX Hidden callback",hMaxHidden,oMaxHidden);
    H(rewardtrace::kCoopTicketsAdResult,"CoopTickets business ad callback",hCoopTicketsAdResult,oCoopTicketsAdResult);
    H(rewardtrace::kDailyFreePackAdResult,"DailyFreePack business ad callback",hDailyFreePackAdResult,oDailyFreePackAdResult);
    H(rewardtrace::kChuseokAdResult,"Chuseok business ad callback",hChuseokAdResult,oChuseokAdResult);
    H(rewardtrace::kCoopBoostAdResult,"CoopBoost business ad callback",hCoopBoostAdResult,oCoopBoostAdResult);
    H(rewardtrace::kRpcCoopTicketsMoveNext,"RPC CoopTickets MoveNext",hRpcCoopTickets,oRpcCoopTickets);
    H(rewardtrace::kRpcDailyFreePackMoveNext,"RPC DailyFreePack MoveNext",hRpcDailyFree,oRpcDailyFree);
    H(rewardtrace::kRpcChuseokMoveNext,"RPC Chuseok MoveNext",hRpcChuseok,oRpcChuseok);
    H(rewardtrace::kRpcCoopBoostMoveNext,"RPC CoopBoost MoveNext",hRpcCoopBoost,oRpcCoopBoost);
    H(rewardtrace::kCoopTicketsSuccess,"CoopTickets success callback",hCoopTicketsSuccess,oCoopTicketsSuccess);
    H(rewardtrace::kDailyFreePackSuccess,"DailyFreePack success callback",hDailyFreePackSuccess,oDailyFreePackSuccess);
    H(rewardtrace::kChuseokSuccess1,"Chuseok success callback b__2",hChuseokSuccess1,oChuseokSuccess1);
    H(rewardtrace::kChuseokSuccess2,"Chuseok success callback b__0",hChuseokSuccess2,oChuseokSuccess2);
    H(rewardtrace::kCoopBoostSuccess,"CoopBoost success callback",hCoopBoostSuccess,oCoopBoostSuccess);
    H(rewardtrace::kHandleError,"PerbaseManager.HandleError",hHandleError,oHandleError);
    H(rewardtrace::kHandleServerResult,"PerbaseManager.HandleServerResult",hHandleServerResult,oHandleServerResult);
    H(rewardtrace::kHandleSuccessedResponse,"PerbaseManager.HandleSuccessedResponse",hHandleSuccessedResponse,oHandleSuccessedResponse);
    H(rewardtrace::kSetChuseokReceiveCount,"DataManager.SetChuseokShopFreeReceiveCount",hSetChuseokReceiveCount,oSetChuseokReceiveCount);
    H(rewardtrace::kRefreshCoopTicketUI,"MenuBattle.RefreshCoopTicketUI",hRefreshCoopTicketUI,oRefreshCoopTicketUI);
#undef H
    return ok;
}

static void OnImage(const mach_header *header,std::intptr_t slide){
    if(!header||gInstalled.load(std::memory_order_acquire)||header->magic!=MH_MAGIC_64) return;
    const char *path=nullptr;
    for(std::uint32_t i=0;i<_dyld_image_count();++i) if(_dyld_get_image_header(i)==header){ path=_dyld_get_image_name(i); break; }
    if(!path||!std::strstr(path,"UnityFramework.framework/UnityFramework")) return;
    char uuid[64]{};
    const bool match=UUIDMatches(reinterpret_cast<const mach_header_64*>(header),uuid,sizeof(uuid));
    Log("UnityFramework loaded path=%s slide=0x%llX UUID=%s __TEXT=[0x%llX,0x%llX)",path,static_cast<unsigned long long>(slide),uuid[0]?uuid:"<missing>",static_cast<unsigned long long>(gTextVMAddr),static_cast<unsigned long long>(gTextVMAddr+gTextVMSize));
    if(!match){ Log("REFUSE install: UUID mismatch expected=%s SHA256=%s",rewardtrace::kExpectedUnityFrameworkUUID,rewardtrace::kExpectedUnityFrameworkSHA256); return; }
    if(gTextVMAddr!=0){ Log("REFUSE install: expected __TEXT vmaddr=0 actual=0x%llX",static_cast<unsigned long long>(gTextVMAddr)); return; }
    gMSHookFunction=reinterpret_cast<MSHookFunctionFn>(dlsym(RTLD_DEFAULT,"MSHookFunction"));
    if(!gMSHookFunction){ Log("REFUSE install: MSHookFunction not found; load a Substrate-compatible backend first"); return; }
    gStringLength=reinterpret_cast<Il2CppStringLengthFn>(dlsym(RTLD_DEFAULT,"il2cpp_string_length"));
    gStringChars=reinterpret_cast<Il2CppStringCharsFn>(dlsym(RTLD_DEFAULT,"il2cpp_string_chars"));
    gSlide=slide;
    bool expected=false;
    if(!gInstalled.compare_exchange_strong(expected,true,std::memory_order_acq_rel)) return;
    Log("installing read-only trace hooks; arguments/results/RPC payloads remain unchanged");
    Log("install complete status=%s",InstallAllHooks()?"ALL_HOOKS_HAVE_ORIGINAL":"PARTIAL_CHECK_LOG");
}
} // namespace rt

__attribute__((constructor)) static void RewardTraceInit(){
    openlog("RewardTrace",LOG_PID|LOG_NDELAY,LOG_USER);
    rt::Log("dylib loaded; waiting for exact UnityFramework build");
    _dyld_register_func_for_add_image(rt::OnImage);
}
