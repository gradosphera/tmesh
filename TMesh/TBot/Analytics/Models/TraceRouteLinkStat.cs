using NodaTime;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Analytics.Models
{
    public class TraceRouteLinkStat
    {
        public int NetworkId { get; set; }
        public LocalDate RecDate { get; set; }
        public uint ViaDeviceId { get; set; }
        public uint ToDeviceId { get; set; }
        public uint FromDeviceId { get; set; }
        public short Count { get; set; }
        public float? AvgSnr { get; set; }
        public float AvgHops { get; set; }
        public int? AvgDistance { get; set; }
        public int? AvgLinkLength { get; set; }
        public int WithSnrCount { get; set; }
        public int WithDistanceCount { get; set; }
        public int WithLinkLengthCount { get; set; }
    }
}
