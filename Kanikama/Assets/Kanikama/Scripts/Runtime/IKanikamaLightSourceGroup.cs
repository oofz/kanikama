﻿using System.Collections.Generic;

namespace Kanikama
{
    public interface IKanikamaLightSourceGroup
    {
        void OnBakeSceneStart();
        void Rollback();
        bool Contains(object obj);
        IList<KanikamaLightSource> GetLightSources();
    }
}