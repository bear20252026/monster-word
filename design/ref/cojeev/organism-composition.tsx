"use client";
import * as React from "react";
import { animate, AnimatePresence, useMotionValue, useMotionValueEvent } from "motion/react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Bubble, BubbleContent, BubbleRow } from "@/components/ui/bubble";
import { InputGroup, InputGroupInput, InputGroupButton } from "@/components/ui/input-group";
import { MessageScroller } from "@/components/ui/message-scroller";
import { Button } from "@/components/ui/button";
import { Icon, IconButton } from "@/components/ui/icon";
import { AnimatedIcon } from "@/components/ui/animated-icon";
import { Item, ItemContent, ItemTitle, ItemDescription } from "@/components/ui/item";
import { Progress } from "@/components/ui/progress";
import { Meta } from "@/components/ui/typography";
import { Shape } from "@/components/ui/shape";
import { MotionPresence, MotionSurface } from "@/components/ui/presence";
import { AssemblyPart, type AssemblyPartProps } from "@/components/ui/assembly-part";
import { floatingContour, organismGeometry, type AssemblyPartId, type OrganismKind } from "@/lib/cojeev/assembly-geometry";
import { useChoreography, trackMotion, motionTokens } from "@/lib/cojeev-motion/choreography";
import { useMotionVisibility } from "@/lib/cojeev-motion/use-motion-visibility";
import { useFlowGroup } from "@/lib/cojeev-motion/use-flow";
import { assignMotionRef } from "@/lib/cojeev-motion/refs";
import { cn } from "@/lib/utils";
import { AssemblyParticles } from "@/lib/cojeev/assembly-particles";

export type OrganismItem={id:string;label:string;description?:string;icon?:string};
export type OrganismMessage={id:string;text:string;from?:"agent"|"user"};
export type OrganismState={draft:string;following:boolean;saved:boolean;completed:string[];selected:string;messages:OrganismMessage[];notice:string;noticeKind?:OrganismKind;profileComposer?:boolean;focusRemainingSeconds?:number;focusRunning?:boolean;focusEndsAt?:number|null;rsvp?:"yes"|"no"|null};
export type OrganismAction={kind:OrganismKind;action:"send"|"follow"|"save"|"toggle"|"select"|"clear"|"suggest"|"message"|"start"|"pause"|"reset"|"complete"|"rsvp";value?:string;item?:OrganismItem;checked?:boolean};
export type OrganismCompositionProps=Omit<React.ComponentProps<"section">,"onChange">&{
  kind?:OrganismKind;
  /** False separates the native roots into floating silhouettes. Quiet mode stays usable. */
  assembled?:boolean;
  /** Decorative seed count for an assembly scene. Zero leaves a plain usable composition. */
  particleCount?:number;
  name?:string;
  description?:string;
  initials?:string;
  /** Up to four task or dock items. */
  items?:OrganismItem[];
  /** Real local session length, clamped to 1–86400 seconds. Changing it resets the session. */
  durationSeconds?:number;
  inviteDate?:string;
  inviteTime?:string;
  inviteLocation?:string;
  participants?:{name:string;initials:string}[];
  state?:OrganismState;
  defaultState?:Partial<OrganismState>;
  onStateChange?:(state:OrganismState)=>void;
  onAction?:(action:OrganismAction)=>void;
  onSettledChange?:(settled:boolean)=>void;
};
const sampleMessages:OrganismMessage[]=[
  {id:"sample-1",from:"agent",text:"A little space for a good idea. What are we making?"},
  {id:"sample-2",from:"user",text:"Something useful, with a little personality."},
  {id:"sample-3",from:"agent",text:"That sounds like our kind of project. ✳"},
];
const initialState:OrganismState={draft:"",following:false,saved:false,completed:["brief"],selected:"home",messages:sampleMessages,notice:""};
const tasks:OrganismItem[]=[{id:"brief",label:"Find the feeling",description:"Collect three good references",icon:"compass"},{id:"assets",label:"Make the first sketch",description:"Keep it loose. Keep it yours.",icon:"pencil"},{id:"share",label:"Share a little progress",description:"A first draft is enough",icon:"send"}];
const destinations:OrganismItem[]=[{id:"home",label:"Home",description:"Your place to begin",icon:"house"},{id:"files",label:"Files",description:"The useful things, together",icon:"folder"},{id:"inbox",label:"Inbox",description:"A little room for new ideas",icon:"inbox"}];
const titles:Record<OrganismKind,string>={profile:"Alex Rivera","side-panel":"Small things,\nbig momentum.",dock:"A place for everything.",chat:"Studio chat",focus:"One good thing.",invite:"A little studio time.",dashboard:"Small things,\nbig momentum."};
const defaultParticipants=[{name:"Mia Kim",initials:"MK"},{name:"Noor Ali",initials:"NA"},{name:"You",initials:"Y"}];
export function normalizeFocusDuration(value=1500){return Number.isFinite(value)?Math.max(1,Math.min(86400,Math.round(value))):1500}
/** The countdown follows elapsed wall time, including time spent in a hidden tab. */
export function focusSecondsRemaining(deadline:number,now=Date.now()){return Number.isFinite(deadline)&&Number.isFinite(now)?Math.max(0,Math.ceil((deadline-now)/1000)):0}
const tones=["blue","yellow","pink","olive"] as const;

/** Six distinct compositions; replay retains each composition's real native roots and state. */
export function OrganismComposition({kind="profile",assembled=true,particleCount=0,name,description,initials="AR",items,durationSeconds=1500,inviteDate="Friday, 18 September",inviteTime="15:00–16:00",inviteLocation="The studio · online",participants=defaultParticipants,state:controlled,defaultState,onStateChange,onAction,onSettledChange,className,style,ref,...props}:OrganismCompositionProps){
  const host=React.useRef<HTMLElement|null>(null),composerInput=React.useRef<HTMLInputElement>(null);
  const attach=React.useCallback((node:HTMLElement|null)=>{host.current=node;return assignMotionRef(ref,node)},[ref]);
  const dockFlowRef=useFlowGroup<HTMLElement>(attach,{kind:"pill",itemSelector:'[data-assembly-part^="tool-"]',activeSelector:'[aria-pressed="true"]'});
  const [width,setWidth]=React.useState(360);
  const [local,setLocal]=React.useState<OrganismState>(()=>({...initialState,...defaultState}));
  const state=controlled??local;
  const duration=normalizeFocusDuration(durationSeconds);
  const remaining=Math.max(0,Math.min(duration,state.focusRemainingSeconds??duration));
  const latest=React.useRef({state,controlled,onStateChange,onAction});
  React.useEffect(()=>{latest.current={state,controlled,onStateChange,onAction}},[state,controlled,onStateChange,onAction]);
  const previousDuration=React.useRef(duration);
  const update=React.useCallback((patch:Partial<OrganismState>)=>{const current=latest.current,next={...current.state,...patch};latest.current={...current,state:next};if(!current.controlled)setLocal(next);current.onStateChange?.(next)},[]);
  React.useEffect(()=>{
    if(previousDuration.current===duration)return;
    previousDuration.current=duration;
    update({focusRemainingSeconds:duration,focusRunning:false,focusEndsAt:null});
  },[duration,update]);
  React.useEffect(()=>{
    if(kind!=="focus"||!state.focusRunning)return;
    const deadline=state.focusEndsAt??Date.now()+(latest.current.state.focusRemainingSeconds??duration)*1000;
    if(state.focusEndsAt==null)update({focusEndsAt:deadline});
    let complete=false;
    const tick=()=>{
      const seconds=focusSecondsRemaining(deadline);
      if(seconds===0){if(complete)return;complete=true;update({focusRemainingSeconds:0,focusRunning:false,focusEndsAt:null,notice:"Focus session complete.",noticeKind:"focus"});latest.current.onAction?.({kind:"focus",action:"complete"});}
      else if(seconds!==latest.current.state.focusRemainingSeconds)update({focusRemainingSeconds:seconds});
    };
    const interval=window.setInterval(tick,250);document.addEventListener("visibilitychange",tick);tick();
    return()=>{window.clearInterval(interval);document.removeEventListener("visibilitychange",tick)};
    // The deadline stays stable while tick updates only the displayed seconds.
  },[kind,state.focusRunning,state.focusEndsAt,duration,update]);
  const serial=React.useRef(0),focusComposer=React.useRef(false);
  const messagePrefix=React.useId();
  const {quiet}=useChoreography();
  const {enabled,inView}=useMotionVisibility(host);
  const scattered=!assembled&&!quiet;
  const available=(items??(kind==="dock"?destinations:tasks)).slice(0,4);
  const geometry=React.useMemo(()=>organismGeometry(kind,width,scattered,{profileComposer:state.profileComposer,itemCount:available.length}),[kind,width,scattered,state.profileComposer,available.length]);
  const origins=React.useMemo(()=>organismGeometry(kind,width,true,{profileComposer:state.profileComposer,itemCount:available.length}),[kind,width,state.profileComposer,available.length]);
  const ids=Object.keys(geometry.parts) as AssemblyPartId[];
  const geometryKey=JSON.stringify(geometry.parts);
  // A new visit to the same destination is a new transition, including quick reversals.
  const targetKey=React.useMemo(()=>({kind,width,scattered,geometryKey}),[kind,width,scattered,geometryKey]);
  const [rested,setRested]=React.useState<Record<string,object>>({});
  const settled=quiet||ids.every(id=>rested[id]===targetKey);
  const visible=!scattered&&settled;
  const stageHeight=useMotionValue(geometry.height);
  const [initialHeight]=React.useState(geometry.height);
  useMotionValueEvent(stageHeight,"change",height=>{if(host.current)host.current.style.height=`${height}px`});
  React.useEffect(()=>{
    if(quiet){stageHeight.jump(geometry.height);return}
    // Expand before parts arrive; keep outgoing taller bounds until every root settles.
    if(geometry.height<stageHeight.get()&&!settled)return;
    return trackMotion(animate(stageHeight,geometry.height,{duration:.55,ease:[...motionTokens.ease.enter]}));
  },[geometry.height,settled,quiet,stageHeight]);
  const idsKey=ids.join("|");
  const restCallbacks=React.useMemo(()=>Object.fromEntries(idsKey.split("|").map(id=>[id,()=>setRested(previous=>previous[id]===targetKey?previous:{...previous,[id]:targetKey})])),[targetKey,idsKey]);
  React.useEffect(()=>{if(!host.current)return;const observer=new ResizeObserver(([entry])=>{if(entry.contentRect.width>0)setWidth(Math.round(entry.contentRect.width))});observer.observe(host.current);return()=>observer.disconnect()},[]);
  React.useEffect(()=>onSettledChange?.(visible),[visible,onSettledChange]);
  React.useEffect(()=>{if(visible&&focusComposer.current&&state.profileComposer){focusComposer.current=false;composerInput.current?.focus()}},[visible,state.profileComposer]);
  const dispatch=(action:Omit<OrganismAction,"kind">)=>onAction?.({...action,kind});
  const complete=available.filter(item=>state.completed.includes(item.id)).length;
  const progress=available.length?Math.round(complete/available.length*100):0;
  function send(){const text=state.draft.trim();if(!text)return;update({draft:"",messages:[...state.messages,{id:`${messagePrefix}-${++serial.current}`,from:"user",text}],notice:kind==="profile"?"Note saved":"Message added to this page.",noticeKind:kind});dispatch({action:"send",value:text})}
  function toggle(item:OrganismItem){const checked=!state.completed.includes(item.id);update({completed:checked?[...state.completed,item.id]:state.completed.filter(id=>id!==item.id)});dispatch({action:"toggle",item,checked})}
  function focusAction(action:"start"|"pause"|"reset"){
    if(action==="start"){const seconds=remaining||duration;update({focusRunning:true,focusRemainingSeconds:seconds,focusEndsAt:Date.now()+seconds*1000,notice:"",noticeKind:"focus"})}
    else if(action==="pause")update({focusRunning:false,focusRemainingSeconds:state.focusEndsAt?focusSecondsRemaining(state.focusEndsAt):remaining,focusEndsAt:null});
    else update({focusRunning:false,focusRemainingSeconds:duration,focusEndsAt:null,notice:"",noticeKind:"focus"});
    dispatch({action});
  }
  function rsvp(value:"yes"|"no"){update({rsvp:value,notice:value==="yes"?"RSVP: yes. Kept on this page.":"RSVP: no. Kept on this page.",noticeKind:"invite"});dispatch({action:"rsvp",value,checked:value==="yes"})}
  const title=name??titles[kind];
  const piece=(id:AssemblyPartId,children:React.ReactElement,extra:Partial<AssemblyPartProps>={})=>{
    const rect=geometry.parts[id];if(!rect)return null;
    const ready=!scattered&&(quiet||rested[id]===targetKey);
    return <AssemblyPart key={id} identity={id} transitionKey={targetKey} rect={rect} from={quiet?undefined:origins.parts[id]} fromContour={floatingContour(id)} contour={scattered?floatingContour(id):id==="avatar"?"circle":"rounded"} radius={id==="badge"||id==="composer"?24:18} tone={tones[ids.indexOf(id)%tones.length]} delay={scattered?0:ids.indexOf(id)*.035} reveal={ready} interactive={ready} release={ready} floating={scattered&&enabled&&inView} immediate={quiet||!enabled||!inView} onRest={restCallbacks[id]} {...extra}>{children}</AssemblyPart>;
  };
  const sendConfirmed=kind==="chat"&&state.noticeKind==="chat"&&state.notice==="Message added to this page.";
  const composer=()=>piece("composer",<InputGroup className="v-organism__composer">
    <InputGroupInput ref={composerInput} className="v-assembly-content" aria-label={kind==="profile"?"Write a note":"Your message"} placeholder={kind==="profile"?"A little hello…":"Add your thought…"} value={state.draft} onChange={event=>update({draft:event.target.value,...(kind==="chat"?{notice:""}:{})})} onKeyDown={event=>{if(event.key==="Enter"&&!event.nativeEvent.isComposing){event.preventDefault();send()}}}/>
    <InputGroupButton className="v-assembly-content" aria-label={kind==="profile"?"Save note":"Send message"} disabled={!state.draft.trim()} onClick={send}>{kind==="chat"?<AnimatedIcon name={sendConfirmed?"check":"arrow-up"} preset={sendConfirmed?"validation":"draw"}/>:<Icon name="arrow-up"/>}</InputGroupButton>
  </InputGroup>);
  const elements:React.ReactNode[]=[piece("surface",<Card className="v-organism__surface" aria-hidden="true"/>,{interactive:false})];
  if(kind==="profile")elements.push(
    piece("cover",<Card variant="blue" className="v-organism__cover" aria-hidden="true"><CardContent className="v-assembly-content v-organism__cover-art"><Shape name="daisy-12"/><Shape name="ribbon-soft"/><Shape name="clover-soft"/></CardContent></Card>,{interactive:false}),
    piece("avatar",<Avatar variant="yellow" className="v-organism__avatar"><AvatarFallback className="v-assembly-content">{initials}</AvatarFallback></Avatar>),
    piece("badge",<Badge variant="olive"><span className="v-assembly-content">Independent</span></Badge>),
    piece("identity",<CardHeader className="v-organism__identity"><CardContent className="v-assembly-content"><CardTitle>{title}</CardTitle><CardDescription>{description??"Making useful things feel human."}</CardDescription></CardContent></CardHeader>),
    piece("stats",<CardContent className="v-organism__stats"><span className="v-assembly-content"><b>12</b><Meta>collections</Meta></span><span className="v-assembly-content"><b>08</b><Meta>projects</Meta></span><span className="v-assembly-content"><Icon name="compass"/><Meta>Everywhere</Meta></span></CardContent>),
    piece("primary",<Button variant="accent" aria-pressed={state.following} onClick={()=>{update({following:!state.following});dispatch({action:"follow",checked:!state.following})}}><span className="v-assembly-content v-organism__button-label"><Icon name={state.following?"check":"plus"}/>{state.following?"Following":"Follow"}</span></Button>),
    piece("secondary",<Button variant="secondary" aria-expanded={!!state.profileComposer} onClick={()=>{focusComposer.current=!state.profileComposer;update({profileComposer:!state.profileComposer});dispatch({action:"message",checked:!state.profileComposer})}}><span className="v-assembly-content v-organism__button-label"><Icon name="message-circle"/>Message</span></Button>),
    piece("save",<IconButton variant="cream" size="sm" aria-label="Save profile" aria-pressed={state.saved} onClick={()=>{update({saved:!state.saved});dispatch({action:"save",checked:!state.saved})}}><Icon className="v-assembly-content" name={state.saved?"check":"bookmark"}/></IconButton>),
    state.profileComposer?composer():null,
  );
  else if(kind==="dock")elements.push(
    piece("identity",<CardContent className="v-organism__dock-heading"><Meta className="v-assembly-content">{name??"YOUR EVERYDAY TOOLS"}</Meta></CardContent>),
    piece("avatar",<Avatar variant="yellow" className="v-organism__dock-spark"><AvatarFallback className="v-assembly-content"><Shape name="clover-soft" /></AvatarFallback></Avatar>),
    ...available.map((item,index)=>piece(`tool-${index}`,<Button variant={state.selected===item.id?"secondary":"ghost"} data-morph="fill" data-r="19" className="v-organism__dock-tool" aria-label={item.label} aria-pressed={state.selected===item.id} onClick={()=>{update({selected:item.id});dispatch({action:"select",item})}}><span className="v-assembly-content"><AnimatedIcon name={item.icon??"circle"} size="lg"/><span className="v-organism__tool-name" title={item.label}>{item.label}</span></span></Button>)),
    piece("caption",<CardContent className="v-organism__dock-caption" role="status"><Meta className="v-assembly-content">{available.find(item=>item.id===state.selected)?.description??available.find(item=>item.id===state.selected)?.label??"Choose a tool to make it yours."}</Meta></CardContent>),
  );
  else if(kind==="chat")elements.push(
    piece("avatar",<Avatar variant="pink" className="v-organism__chat-avatar"><AvatarFallback className="v-assembly-content">SJ</AvatarFallback></Avatar>),
    piece("identity",<CardHeader className="v-organism__identity v-organism__identity--chat"><CardContent className="v-assembly-content"><CardTitle>{title}</CardTitle><Meta><Shape name="pebble-soft" />Here for a good idea</Meta></CardContent></CardHeader>),
    piece("save",<IconButton variant="cream" size="sm" aria-label="Clear conversation" onClick={()=>{update({messages:[],notice:""});dispatch({action:"clear"})}}><span className="v-assembly-content"><AnimatedIcon name="trash-2"/></span></IconButton>),
    piece("badge",<CardContent className="v-organism__chat-date"><Meta className="v-assembly-content">{description??"A conversation, just for this page"}</Meta></CardContent>),
    piece("thread",<CardContent className="v-organism__thread"><CardContent className="v-assembly-content v-organism__thread-content"><MessageScroller scrollbarType="auto" style={{"--h":"100%"} as React.CSSProperties} aria-label="Studio conversation" role="log"><Bubble className="v-organism__conversation"><MotionPresence>{state.messages.map(message=><MotionSurface key={message.id} asChild preset="rise"><BubbleRow variant={message.from==="user"?"me":"default"} className="v-organism__message"><BubbleContent data-morph="fill" className="v-organism__bubble" variant={message.from==="user"?"me":"tail"}><span className="sr-only">{message.from==="user"?"You: ":"Studio: "}</span>{message.text}</BubbleContent></BubbleRow></MotionSurface>)}</MotionPresence>{state.messages.length===0&&<Meta className="v-organism__empty">A fresh page.<br/>What shall we make of it?</Meta>}</Bubble></MessageScroller></CardContent></CardContent>),
    composer(),
    piece("caption",<Meta className="v-organism__local-note"><span className="v-assembly-content">Local notes · no messages leave this page</span></Meta>),
  );
  else if(kind==="focus")elements.push(
    piece("identity",<CardHeader className="v-organism__identity v-organism__focus-heading"><CardContent className="v-assembly-content"><Meta>A LITTLE ROOM TO FOCUS</Meta><CardTitle>{title}</CardTitle></CardContent></CardHeader>),
    piece("cover",<CardContent className="v-organism__focus-art" aria-hidden="true"><Shape className="v-assembly-content" name="daisy-12"/></CardContent>,{interactive:false}),
    piece("stats",<CardContent className="v-organism__clock"><Meta className="v-assembly-content" role="timer" aria-live="off" aria-label={`${Math.floor(remaining/60)} minutes ${remaining%60} seconds remaining`}>{String(Math.floor(remaining/60)).padStart(2,"0")}<span>:</span>{String(remaining%60).padStart(2,"0")}</Meta><Meta className="v-assembly-content">{remaining===0?"A good little stretch of focus.":state.focusRunning?"One thing at a time.":remaining<duration?"Take your time. Come back ready.":"Ready when you are."}</Meta></CardContent>),
    piece("progress",<CardContent className="v-organism__progress"><Progress className="v-assembly-content" value={(duration-remaining)/duration*100} aria-label="Focus session progress"/></CardContent>),
    piece("badge",<Meta className="v-organism__focus-description"><span className="v-assembly-content">{description??"No rush. Just a little uninterrupted time."}</span></Meta>),
    piece("primary",<Button variant="accent" onClick={()=>focusAction(state.focusRunning?"pause":"start")}><span className="v-assembly-content v-organism__button-label"><AnimatedIcon name={state.focusRunning?"pause":"play"}/>{state.focusRunning?"Pause":remaining===0?"Start again":remaining<duration?"Resume":"Start focusing"}</span></Button>),
    piece("secondary",<IconButton variant="cream" aria-label="Reset focus session" onClick={()=>focusAction("reset")}><span className="v-assembly-content"><AnimatedIcon name="refresh-cw"/></span></IconButton>),
    piece("caption",<Meta className="v-organism__local-note"><span className="v-assembly-content">A local timer. No sound, no notifications.</span></Meta>),
  );
  else if(kind==="invite")elements.push(
    piece("cover",<Card variant="olive" className="v-organism__invite-cover" aria-hidden="true"><CardContent className="v-assembly-content"><Shape name="daisy-12"/><Shape name="seed-wing"/><Meta>GOOD COMPANY.<br/>BETTER IDEAS.</Meta></CardContent></Card>,{interactive:false}),
    piece("identity",<CardHeader className="v-organism__identity v-organism__invite-heading"><CardContent className="v-assembly-content"><CardTitle>{title}</CardTitle><CardDescription>{description??"Bring a small idea. Leave with a little momentum."}</CardDescription></CardContent></CardHeader>),
    piece("stats",<CardContent className="v-organism__event-details"><Meta className="v-assembly-content"><Icon name="calendar"/><span>{inviteDate} · {inviteTime}</span></Meta><Meta className="v-assembly-content"><Icon name="compass"/><span>{inviteLocation}</span></Meta></CardContent>),
    piece("participants",<CardContent className="v-organism__participants"><span className="v-assembly-content v-organism__avatar-stack">{participants.slice(0,4).map((person,index)=><Avatar key={`${person.name}-${index}`} variant={tones[index]} title={person.name} aria-label={person.name}><AvatarFallback>{person.initials}</AvatarFallback></Avatar>)}</span><Meta className="v-assembly-content">{participants.length?"A few good people.":"Room for good company."}</Meta></CardContent>),
    piece("caption",<Meta className="v-organism__invite-status"><span className="v-assembly-content">{state.rsvp==="yes"?"You're in · saved on this page." :state.rsvp==="no"?"Maybe next time · saved on this page.":"Your RSVP stays on this page."}</span></Meta>),
    piece("primary",<Button variant={state.rsvp==="yes"?"secondary":"accent"} aria-pressed={state.rsvp==="yes"} onClick={()=>rsvp("yes")}><span className="v-assembly-content v-organism__button-label"><AnimatedIcon name={state.rsvp==="yes"?"check":"plus"}/>{state.rsvp==="yes"?"Count me in":"I'll be there"}</span></Button>),
    piece("secondary",<Button variant="ghost" aria-pressed={state.rsvp==="no"} onClick={()=>rsvp("no")}><span className="v-assembly-content">{state.rsvp==="no"?"Not this time ✓":"Maybe next time"}</span></Button>),
  );
  else elements.push(
    piece("identity",<CardHeader className="v-organism__identity v-organism__panel-heading"><CardContent className="v-assembly-content"><Meta>{description??"PROJECT / STUDIO REFRESH"}</Meta><CardTitle>{title}</CardTitle></CardContent></CardHeader>),
    piece("cover",<CardContent className="v-organism__panel-art" aria-hidden="true"><Shape className="v-assembly-content" name="seed-wing"/><Shape className="v-assembly-content" name="clover-soft"/></CardContent>,{interactive:false}),
    piece("badge",<CardContent className="v-organism__task-summary"><Badge variant="olive" className="v-assembly-content">{complete} / {available.length}</Badge><Meta className="v-assembly-content">{available.length===0?"Nothing queued. A little breathing room.":complete===available.length?"Look at that. All done.":"A few good steps forward"}</Meta></CardContent>),
    ...available.map((item,index)=>piece(`task-${index}`,<Item variant="flat" className="v-organism__task" data-complete={state.completed.includes(item.id)} aria-pressed={state.completed.includes(item.id)} onClick={()=>toggle(item)}><span className="v-assembly-content v-organism__task-mark"><Shape name="pebble-soft"/><AnimatedIcon name={state.completed.includes(item.id)?"check":item.icon??"circle"}/></span><ItemContent className="v-assembly-content"><ItemTitle>{item.label}</ItemTitle><ItemDescription>{item.description}</ItemDescription></ItemContent><Meta className="v-assembly-content v-organism__task-number">{String(index+1).padStart(2,"0")}</Meta></Item>)),
    piece("progress",<CardContent className="v-organism__progress v-organism__panel-progress"><Progress className="v-assembly-content" value={progress} aria-label="Completed tasks"/><Meta className="v-assembly-content">{progress}%</Meta></CardContent>),
    piece("secondary",<Button variant="ghost" size="sm" onClick={()=>{update({completed:[]});dispatch({action:"clear"})}}><span className="v-assembly-content v-organism__button-label"><AnimatedIcon name="refresh-cw"/>Start fresh</span></Button>),
  );
  return <section {...props} ref={kind==="dock"&&visible?dockFlowRef:attach} data-slot="organism-composition" data-kind={kind} data-particle-count={particleCount} data-assembled={!scattered} data-settled={settled} aria-label={props["aria-label"]??title} className={cn("v-organism",kind==="dock"&&"v-seg",className)} style={{...style,height:initialHeight}}>
    <AnimatePresence initial={false}>{elements}</AnimatePresence>
    {particleCount > 0 && <AssemblyParticles hostRef={host} assembled={!scattered} settled={settled} count={particleCount} />}
    <span className="sr-only" role="status">{state.noticeKind===kind?state.notice:""}</span>
  </section>;
}

export type OrganismProps=Omit<OrganismCompositionProps,"kind">;
export function ProfileCard(props:OrganismProps){return <OrganismComposition {...props} kind="profile"/>}
export function WorkSidePanel(props:OrganismProps){return <OrganismComposition {...props} kind="side-panel"/>}
export function ActionDock(props:OrganismProps){return <OrganismComposition {...props} kind="dock"/>}
export function ConversationPanel(props:OrganismProps){return <OrganismComposition {...props} kind="chat"/>}
export function FocusSession(props:OrganismProps){return <OrganismComposition {...props} kind="focus"/>}
export function InviteCard(props:OrganismProps){return <OrganismComposition {...props} kind="invite"/>}
/** @deprecated Historical catalogue alias. Use WorkSidePanel for the compact task composition. */
export function CompactDashboard(props:OrganismProps){return <OrganismComposition {...props} kind="dashboard"/>}
export type {OrganismKind} from "@/lib/cojeev/assembly-geometry";
