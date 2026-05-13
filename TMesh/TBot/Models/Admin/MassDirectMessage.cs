using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TBot.Models.Admin
{
    public class MassDirectMessage
    {
        public string Text { get; set; }

        public string NodeNameRegexPattern { get; set; }

        public int? MaxNodeAgeHours { get; set; }

        public int NetworkId { get; set; }
    }
}
