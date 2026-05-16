using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Analytics.Dto
{
    public class TraceRouteInfo
    {
        public List<TraceRoutePairInfo> Route { get; set; }
        public List<TraceRoutePairInfo> RouteBack { get; set; }
    }
}
