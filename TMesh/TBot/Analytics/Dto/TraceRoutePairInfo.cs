using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Analytics.Dto
{
    public class TraceRoutePairInfo
    {
        public long ToDeviceId { get; set; }

        public long FromDeviceId { get; set; }

        public float? Snr { get; set; }
    }
}
